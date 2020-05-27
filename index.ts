import * as functions from 'firebase-functions'
import * as admin from 'firebase-admin'

// Production init (deploy to Google)
admin.initializeApp()

// Testing init (local console emulator)
// Must first run download cert json and run command in terminal:
// export GOOGLE_APPLICATION_CREDENTIALS="/path/to/certificate.json"
// admin.initializeApp({
//     credential: admin.credential.applicationDefault(),
//     databaseURL: 'https://flashchat55555.firebaseio.com'
// });


export const revokeDuplicateNotificationTokens =
functions.firestore.document("users/{userId}/notificationTokens/{tokenDocId}").onCreate(async (snapshot, context) => {
    console.log("New notification token added.")

    // Get uid
    const userDoc = snapshot.ref.parent.parent

    try {
        if (!userDoc) {
            throw new Error("User document could not be found.")
        }
        const userId = userDoc.id
        console.log("Token added for user with ID", userId)
    
        const data = snapshot.data()
        if (!data) {
            throw new Error("Document data could not be read.")
        }

        // Token string is the "token" field's value
        const token = data.token

        // Get all duplicate tokens across all users
        const tokenDocs = await admin.firestore().collectionGroup("notificationTokens").where("token", "==", token).get()
        console.log("Checking collection group for users with the same token.")
        
        // Remove duplicate tokens
        const tokenRemovals: Promise<FirebaseFirestore.WriteResult>[] = []
        tokenDocs.forEach(result => {
            const olderUserDoc = result.ref.parent.parent
            try {
                if (!olderUserDoc) {
                    throw new Error("Other user's document could not be found.")
                }
                const olderUserId = olderUserDoc.id
                
                // Don't remove token from ourself
                if (olderUserId !== userId) {
                    tokenRemovals.push(result.ref.delete())
                    console.log("Promising to delete same token from user with ID", olderUserId)
                }
            } catch (error) {
                console.log(error)
            }
        })

        // Finish when all removals are successful
        if (tokenRemovals.length === 0) {
            console.log("Didn't find any other users with the same token.")
        }
        return Promise.all(tokenRemovals)
    } catch (error) {
        return "Error: " + error
    }
})


export const sendNewMessageNotification =
functions.firestore.document("rooms/{roomId}/messages/{messageId}").onCreate(async (snapshot, context) => {
    console.log("New message posted somewhere.")

    // Begin by assuming the user might not have a name (just in case)
    // Empty string will be ignored entirely in payload
    let senderName = ""

    // Try to get the document
    const message = snapshot.data()

    try {
        if (!message) {
            throw new Error("Message not found.")
        }

        // Get message values
        const senderUid = message.sender
        const messageBody = message.body
        console.log("UID", senderUid, "says", messageBody)
    
        // Get sender display name from admin.auth().getUser(senderUid) -> displayName
        // If we can't find the user at all, no name (title) will be provided
        try {
            const senderRecord = await admin.auth().getUser(senderUid)
            console.log("Got sender's user record.")

            // Add the sender name, assuming we found it
            if (senderRecord.displayName) {
                senderName = senderRecord.displayName
                console.log("Identified user by name", senderName)
            }
        } catch (error) {
            console.log("Error getting sender's user record:", error)
        }

        // Get path to room
        const roomDoc = snapshot.ref.parent.parent
        if (!roomDoc) {
            throw new Error("Room not found.")
        }
        console.log("Room has ID", roomDoc.id)

        // Get participants collection path
        const participantsCollection = roomDoc.collection("participants")

        // Get participant UIDs
        const participantDocs = await participantsCollection.get()

        // Note whether or not this is a group chat
        const participantsCount = participantDocs.docs.length
        console.log("Found", participantsCount, "participants.")
        let roomName = ""
        if (participantsCount > 2) {
            roomName = "Group Chat"
        }

        // Create array of promises to get all tokens asynchronously
        const tokenPromises: Promise<FirebaseFirestore.QuerySnapshot>[] = []

        // Get each matching user document
        participantDocs.forEach(participantDoc => {
            const uid = participantDoc.get("uid")
            if (!uid) {
                console.log("No UID found in document with ID", participantDoc.id)
                return // "continue"
            }
            if (uid === senderUid) {
                console.log("No need to send notification to sender.")
                return
            }
            
            // Get this user's tokens
            const tokensSnapshot = admin.firestore().collection(`users/${uid}/notificationTokens`).get()
            tokenPromises.push(tokensSnapshot)
        })

        // Wait until we've found all tokens
        const tokensByUser = await Promise.all(tokenPromises)
        console.log("Got", tokensByUser.length, "users' token snapshots.")

        // Collect each token document, so we can remove any bad ones later
        // const tokens: string[] = []
        const tokenRefs: FirebaseFirestore.DocumentReference[] = []
        // Each message is essentially the same, but has a different token in the payload
        const messages: admin.messaging.Message[] = []

        // Look at each user's collection of tokens
        tokensByUser.forEach(userTokens => {
            const tokenDocs = userTokens.docs
            console.log("User has", tokenDocs.length, "tokens.")

            // Look at each token belonging to this user
            tokenDocs.forEach(doc => {
                console.log("Checking token document with ID", doc.id)
    
                const token = doc.data().token
                console.log("Found token", token)
                // tokens.push(token)
                tokenRefs.push(doc.ref)

                // Add message with this token
                messages.push({
                    notification: {
                        title: senderName,
                        body: messageBody
                    },
                    apns: {
                        payload: {
                            aps: {
                                alert: {
                                    subtitle: roomName
                                },
                                sound: "default", // Vibrate
                                badge: 1,
                                mutableContent: true, // Allow app ext to modify; in our case, badge count
                                threadId: roomDoc.id, // For notif centre grouping, and also for badging in-app
                                category: "message" // To change summary at bottom of grouped notifications
                                /* contentAvailable: - for background updates */
                            }
                        }
                    },
                    /* data: { } */
                    token: token
                })

                /*
                    // Increment by one
                    const badgeCount = (user.notifications | 0) + 1
                    // Update badge count
                    await doc.ref.update({notifications: badgeCount})
                */
            })
        })

        // Check that we actually found any tokens, otherwise send anything (kill signal)
        if (messages.length === 0) {
            console.log("None of the users have notification tokens.")
            return messages.length
        }

        /*
            // If we end up using serverside badges, consider the following:
            //- "forEach(async doc => {"
            //- "Promise.all[Settled]", so they can work on each user concurrently
            //- Have to solve the "max listeners exceeded" problem
            //- Payload needs to be customized PER USER, due to the badge
        */
        
        // Send the notifications
        console.log("Attempting to send notifications.")
        const response = await admin.messaging().sendAll(messages)
        console.log("Sent", response.successCount, "messages successfully, with", response.failureCount, "failures.")

        // We will remove any tokens that are no longer valid
        const badTokensRefs: FirebaseFirestore.DocumentReference[] = []

        response.responses.forEach((sendResponse, index) => {
            const error = sendResponse.error
            if (error) {
                console.log("Failed to send message to a token:", error.message)
                console.log("Error code:", error.code)
                // Check cause of error
                if (error.code === "messaging/invalid-registration-token" ||
                    error.code === "messaging/registration-token-not-registered" ||
                    error.code === "messaging/invalid-argument") {
                    // We will remove all of them together later
                    badTokensRefs.push(tokenRefs[index])
                    console.log("Token queued for deletion:", tokenRefs[index])
                }
            }
        })

        // Remove all bad tokens in one batch
        if (badTokensRefs.length > 0) {
            console.log("Adding", badTokensRefs.length, "tokens for batch deletion.")
            const batchRemoval = admin.firestore().batch()
            badTokensRefs.forEach(token => {
                batchRemoval.delete(token)
                console.log("Added token to deletion batch:", token)
            })
            const removals = await batchRemoval.commit()
            console.log("Removed", removals.length, "tokens from the database.")
        }

        // Must return a value to terminate cloud function
        return response
    } catch (error) {
        console.log("Error:", error)
        return "Error: " + error
    }
})