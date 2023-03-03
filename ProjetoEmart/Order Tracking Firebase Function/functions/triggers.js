const functions = require('firebase-functions');
const admin = require ("firebase-admin");

//admin.initializeApp();

const serviceAccount = require("./serviceAccountKey");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: ""
});

const firestore = admin.firestore();



/*
** When a user updates their profile info (email, profile picture, first name, etc)
** We update all the firestore tables that contain copies of that user object
*/
exports.propagateUserProfileUpdates = functions.firestore
.document("users/{userID}")
.onUpdate((change, context) => {
    const userData = change.after.data();
    if (!userData) {
        console.log("no user data");
        return;
    }

    updateChatConversations(userData)
    return null
});

const updateChatConversations = async (userData) => {
    // Update all chat conversations where this user has been the sender
    const querySnapshot = await firestore
        .collectionGroup('thread')
        .where('senderID', '==', userData.id)
        .get()

    let docs = querySnapshot.docs;
    for (let doc of docs) {
        var data = {}
        if (userData.firstName) {
            data['senderFirstName'] = userData.firstName
        }
        if (userData.lastName) {
            data['senderLastName'] = userData.lastName
        }
        if (userData.profilePictureURL) {
            data['senderProfilePictureURL'] = userData.profilePictureURL
        }
        doc.ref.set(data, {merge: true})
    }
}
