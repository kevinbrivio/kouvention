import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {onDocumentCreated} from "firebase-functions/v2/firestore";

initializeApp(); // Init Admin SDK with project default credentials.

const db = getFirestore();
const messaging = getMessaging();

export const onMessageCreated = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const snapshot = event.data; // Document from which just created
    if (!snapshot) return;

    const message = snapshot.data();
    const chatId = event.params.chatId;

    const senderId = message.senderId as string;
    const senderName = message.senderName as string;
    const senderPhotoUrl = (message.senderPhotoUrl as string) ?? "";
    const messageText = message.text as string;

    // Get the chat document to find members and chat metada
    const chatDoc = await db.doc(`chats/${chatId}`).get();
    if (!chatDoc.exists) return;

    const chatData = chatDoc.data();
    if (!chatData) return;
    const members: string[] = chatData.members ?? [];
    const chatName: string = chatData.chatName ?? "";
    const chatType: string = chatData.chatType ?? "direct";

    // Remove sender because they don't need their own notifications
    const recipients = members.filter((uid) => uid !== senderId);
    if (recipients.length === 0) return;

    // Batch-read all recipients user document
    const userDocs = await Promise.all(
      recipients.map((uid) => db.doc(`users/${uid}`).get())
    );

    // store all fcm token
    const tokens: string[] = [];

    for (const userDoc of userDocs) {
      if (!userDoc.exists) continue;

      const fcmToken = userDoc.data()?.fcmTokens;
      if (!fcmToken) continue;

      tokens.push(...Object.keys(fcmToken));
    }

    if (tokens.length === 0) return;

    // build notification title based on chat type
    const title = chatType === "group" ?
      `${senderName} in ${chatName}` :
      senderName;

    // Truncate message preview
    const body = messageText.length > 100 ?
      messageText.substring(0, 100) + "..." :
      messageText;

    const response = await messaging.sendEachForMulticast({
      tokens,
      data: {
        chatId,
        chatType,
        chatName,
        senderId,
        senderName,
        senderPhotoUrl,
        messageText: body,
        title,
        clickAction: "OPEN_CHAT",
      },
      android: {
        priority: "high",
      },
      apns: {
        payload: {
          aps: {
            contentAvailable: true,
          },
        },
        headers: {
          "apns-priority": "10",
        },
      },
    });

    // -- HANDLING ERRORS
    if (response.failureCount > 0) {
      const failedTokens: string[] = [];

      response.responses.forEach((resp, index) => {
        if (!resp.success) {
          const errorCode = resp.error?.code;

          if (
            errorCode === "messaging/invalid-registration-token" ||
            errorCode === "messaging/registration-token-not-registered"
          ) {
            failedTokens.push(tokens[index]);
          }
        }
      });

      // Delete invalid token from firestore
      if (failedTokens.length > 0) {
        const batch = db.batch();

        for (const userDoc of userDocs) {
          if (!userDoc.exists) continue;
          const fcmTokens = userDoc.data()?.fcmTokens;
          if (!fcmTokens) continue;

          const updates: Record<string, FieldValue> = {};

          for (const token of failedTokens) {
            if (token in fcmTokens) {
              updates[`fcmTokens.${token}`] = FieldValue.delete();
            }
          }

          if (Object.keys(updates).length > 0) {
            batch.update(userDoc.ref, updates);
          }
        }

        await batch.commit();
      }
    }
  }
);
