-- Seed default terms and privacy policy content for Groundup Society

insert into public.app_settings (key, value_integer, value_text, description)
values
  (
    'legal_documents_version',
    0,
    '1.0',
    'Version label for terms and privacy policy shown during signup'
  ),
  (
    'terms_content',
    0,
    $terms$Terms and Conditions

Last updated: June 2026

Welcome to Groundup Society. These Terms and Conditions govern your use of the Groundup Society mobile app and your membership at our cafes.

1. Membership
By creating an account, you confirm that the information you provide is accurate and that you are at least 16 years old. You are responsible for keeping your login details secure and for all activity on your account.

2. Rewards and points
Reward points, offers, and redemptions are provided at our discretion. Points have no cash value, may expire, and may be adjusted or withdrawn if we suspect misuse, fraud, or error. Redemptions are subject to product availability and in-store verification.

3. Orders and in-store use
Orders placed through the app are subject to store availability, pricing at the time of purchase, and our standard cafe policies. You agree to present your member QR code when requested for rewards, redemptions, or order collection.

4. Referrals
Referral rewards are only granted when valid referral codes are used in accordance with our referral rules. We may change or discontinue referral promotions at any time.

5. Acceptable use
You agree not to misuse the app, interfere with our systems, attempt to access another member's account, or use the service in any unlawful way.

6. Changes to these terms
We may update these Terms and Conditions from time to time. When we do, we will publish the updated version in the app and may ask you to accept the new version before continuing to use the service.

7. Contact
If you have questions about these terms, contact us at hello@groundupsociety.com or speak to a member of staff in store.$terms$,
    'Terms and conditions shown during signup'
  ),
  (
    'privacy_policy_content',
    0,
    $privacy$Privacy Policy

Last updated: June 2026

Groundup Society ("we", "us", "our") respects your privacy. This policy explains what personal data we collect through the Groundup Society app, how we use it, and the choices available to you.

1. Information we collect
When you create an account, we collect your name, email address, mobile number, and birthday. We also collect information generated through your use of the app, including reward points, referral activity, order history, and profile preferences such as marketing opt-in.

2. How we use your information
We use your information to:
- create and manage your membership account
- process orders and in-store rewards
- operate referral programmes and promotions
- communicate with you about your account, orders, and member benefits
- send marketing communications where you have opted in
- improve our app, stores, and services
- prevent fraud and maintain security

3. Legal basis
We process your personal data to perform our contract with you as a member, to comply with legal obligations, and, where applicable, based on your consent (for example, marketing communications).

4. Sharing your information
We do not sell your personal data. We may share information with trusted service providers who help us operate the app, process orders, or send communications, and with our staff where needed to serve you in store. We may also disclose information if required by law.

5. Data retention
We keep your information for as long as your account is active and for a reasonable period afterwards where needed for legal, accounting, or operational purposes.

6. Your rights
Depending on applicable law, you may have the right to access, correct, or delete your personal data, withdraw consent for marketing, or object to certain processing. To make a request, contact us at privacy@groundupsociety.com.

7. Security
We take reasonable steps to protect your information, but no system is completely secure. Please keep your account credentials confidential.

8. Changes to this policy
We may update this Privacy Policy from time to time. Material changes will be published in the app and may require your acceptance during signup or continued use.

9. Contact
For privacy questions, contact privacy@groundupsociety.com or write to Groundup Society, United Kingdom.$privacy$,
    'Privacy policy shown during signup'
  )
on conflict (key) do update
set
  value_text = excluded.value_text,
  description = excluded.description,
  updated_at = now()
where public.app_settings.value_text is distinct from excluded.value_text
   or public.app_settings.description is distinct from excluded.description;
