-- Email verification has been removed, so nobody is waiting on it.
--
-- Accounts created before that change sit at PENDING with `email_verified = 0`,
-- waiting for a link that no longer exists and that nothing will ever send.
-- Left alone they could not sign in at all — the status check would refuse
-- them for a reason that has ceased to be true.
--
-- They are activated here rather than by asking each of them to do something,
-- because the requirement they failed has been withdrawn, not satisfied.

UPDATE users
   SET status = 'ACTIVE',
       email_verified = 1,
       updated_at = CURRENT_TIMESTAMP
 WHERE status = 'PENDING';

-- Accounts an administrator deliberately suspended or disabled are untouched:
-- those are decisions somebody made, not a side effect of a removed feature.
