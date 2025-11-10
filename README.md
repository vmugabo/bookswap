# BookSwap (Flutter + Firebase)

Welcome! This repository powers BookSwap, a small Flutter app that lets people list books and swap them with other users. The app uses Firebase for authentication, Firestore for data (books, offers, chats) and Firebase Storage for images.

If you just want to try the app right now, open the hosted copy at:

https://bookswap-879ad.web.app

What you'll find when visiting the hosted site
- Sign-in: sign in with email/password, or use Google Sign-In 
- Browse listings: view book cards, tap a book to see details.
- List a book: create a new listing with title, author, condition and optional photo.
- Make offers: if you see a book you like, send a swap offer to the owner.
- Chat: after an offer is created you can open an in-app chat with the other user to coordinate the swap.
- Profile: update your display name and avatar; use the Settings screen to sign out.

Short, friendly overview
- The app stores user profiles in `users/{uid}` documents (displayName, imageUrl, email).
- Books are stored in `books/{bookId}` and include `ownerId` to link the book to a user.
- Offers are held in `offers/{offerId}` and reference the book and the `fromUserId`.
- Chats live in `chats/{chatId}/messages/{messageId}`; chats are created deterministically from two UIDs (smallest_largest) so two users always share the same chat.

Quick tips for testers visiting the hosted site
- If the UI asks you to sign in, pick "Sign in" and use a test email/password or Google account.
- Create a listing, then sign in as another user and send an offer to see the full swap/chat flow.
- If images fail to upload on web, try again — hosting and storage are connected to a development Firebase project and may have temporary limits.


Troubleshooting
- If you see Firestore permission errors: check that rules are deployed for the environment you're using (development vs production) and that the email/user has been created in Firebase Auth.
- For iOS build issues: this project has seen SPM/CocoaPods differences in the past; try running `pod install` in `ios/` or open the workspace in Xcode and resolve package dependencies there.

Thanks for trying BookSwap — if you'd like I can also add a short walkthrough GIF or a video link showing the sign-in → list → offer → chat flow.

``` 
