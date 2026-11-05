# Browsly Prohibited Products Policy

**Status: draft for the owner's approval. It has not had legal review.** Please check it against Bangladesh law with a local adviser before launch.

The AI uses this policy to review each listing. The working copy is in `supabase/functions/moderate-product/policy.ts`, and the two must be kept in step.

## How decisions work

- **Clear pass:** the AI approves it, and the listing goes live.
- **Unsure or a likely breach:** it goes to the admin portal, where an admin makes the final decision. The AI never rejects a seller's product by itself.
- **AI unavailable:** the listing stays in review, and moves to the admin portal after 24 hours.

## Not allowed

| Rule | Examples |
|---|---|
| Illegal or restricted | Anything illegal in Bangladesh, gambling products, hacked accounts, pirated software or media |
| Weapons | Firearms, ammunition, explosives, fireworks, weapons made to hurt |
| Drugs and medicine | Illegal drugs, drug equipment, prescription medicine, anything claiming to cure a disease |
| Alcohol and tobacco | Alcohol, tobacco, vapes, nicotine products |
| Adult | Sexual products or images |
| Counterfeit | Fake or copied branded goods |
| Stolen goods and documents | Stolen goods, identity documents, licences, certificates, bank cards, currency |
| Wildlife | Protected animals, or products made from them |
| Hate or violence | Content promoting hatred or violence |
| Misleading | False descriptions, or things that aren't real products |
| Wrong photos | Photos that don't show the product described |
| Dealing outside Browsly | Phone numbers, links, social media names or payment numbers in a listing |

## Questions for the owner

1. **Tobacco and vapes:** this draft bans them completely. Is that what you want?
2. **Medicine:** this draft bans prescription medicine and cure claims, but allows ordinary vitamins and health products unless the AI is unsure. Is that right?
3. **Phone numbers in listings:** this draft treats them as a breach, because they let buyers avoid the 1% commission and in-app chat. Is that right?
