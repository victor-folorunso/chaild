# Revenue and Referrals

When a user installs your app and subscribes to Chaild, you earn a share of
their subscription every month for as long as they stay subscribed. You do
not need to do anything after integration. Attribution is automatic.

---

## How Attribution Works

When you call `ChaildAuth.initialize()` with your `partnerKey`, that key is
recorded when each new user creates their Chaild account through your app.
Every subscription payment from that user is tracked back to you.

If a user already has a Chaild account from another app, they are not counted
as your referral. Attribution only happens at the moment the account is created.

---

## How Revenue is Split

Chaild uses a time-weighted model. At the end of each month, Chaild looks at
how much time each subscribed user spent in each app. Your share of their
subscription is proportional to how much time they spent in your app relative
to all other apps they use.

If a user signed up specifically through your app (direct referral), your
usage hours are counted double for that user. This rewards you for bringing
users in, but only as long as they actually use your app.

Example:
- User pays 2500 NGN per month
- Your app: 14 weighted hours (7 actual hours, doubled because you referred)
- Other app A: 15 hours
- Other app B: 23 hours
- Total weighted hours: 52
- Your earnings from this user: (14 / 52) x 2500 = 673 NGN

If your app stops being useful to the user and they stop using it, your
earnings from that user go to zero automatically. This keeps the model fair.

---

## Referral Availability

Referrals are only available to registered developer partners. Register at
portal.chaild.app to get a partner key and participate in revenue sharing.

Regular app users cannot earn referral income. If a user wants to earn from
Chaild, they need to build an app that integrates the SDK.

---

## Payouts

Payouts are processed automatically at the start of each month for any
partner with an unpaid balance above the minimum threshold (5000 NGN).

You will receive your payout via the method you configured in the developer
portal. Currently supported:

- Bank transfer (via Flutterwave, Nigerian banks)
- Crypto (USDT and other supported networks)

Set your payout details in the developer portal under Payout Settings. You
will not receive payouts until your bank or wallet details are saved.

You can view your full earnings history and payout history in the developer
portal.

---

## Seeing Your Stats

The developer portal shows:

- Total users you have referred
- Total amount earned (all time)
- Unpaid balance (pending next payout)
- Total paid out
- Breakdown by app if you have multiple apps registered

There is no stats API exposed to the Flutter SDK. Stats are portal-only.

