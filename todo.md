## Gocardless
Link account ✅
What happens when token expires ✅
What happens when agreement auth expires ✅
Show warnings ✅
Unsetting config fields ✅
Stop delete transactions re importing. ✅

## credits
Add credits ✅
Venues ✅
Things ✅
List credits for user ✅
- Link to attendance ✅
- Link to membership ✅
- Link to things ✅
Events ✅
Imports (credits) ✅
Transfer credits ✅
Attendance ✅
Membership ✅
- adding to multiple memberships ✅
Refunds transactions (ensure they don't expire) ✅
venue deleting ✅
Transaction what happens to credits if transaction_who changes ✅
Gocradless handling Tokens/Credits ✅
Auto add tags for transactions ✅
Venues with no value ✅
public display credits ✅
Configerable public message ✅
Email warnings ✅
- old depricated email refactor ✅
- put last_warning_email on member, to avoid unessacery spam ✅
Analysis
- Totals ✅
Honory members ✅ (for credit system)
Registering with invalid nok email. ✅
Updating registration success token price. ✅
Registration email. ✅
## Credits
Auto generate gocradless_name
Other venue algorithems
- split cost
## ssl certificate
## Booking
## Bugs
GoCrAddless. ✅
Text to always use the same Credits reference.
Check gocardless crashing ✅
Fix credit transfur ✅
Trainings Where filter. ✅


### 2025-09-22

Email database backup ✅
Removed outdated information from the success page ✅.
Stop people registering with the same name ✅
Error if backup fails ✅
Change text on Credits page ✅
Magic auth link
llm feature
Auth through llm
Book through llm
Delete from go_cardless
Commitment mode [x]
Show future events in filter [x]
Credit warning email error [x]
Live update attending [x]
Live update today booking [x]
Users adding themselfs twice shouldnt happen [x]
Style auth service for mobile [x]
Redirect after registration form.
Llm enabled for me; if only/first person in channel, then enable, else disable by default. Add whole channel disable option for admin. Maybe pass llm control for admins. [x]
Saving history. [x]
Surface chat list for admins. [x]
Context admin. [x]
Add llm presence. [x]
Credits tool. [x]
Handling if LLM isn't available. [x]
disable messaging if llm is processing. [x]
Fix delta/message syncing. [x]
Fix not coming online when clicking Chat [x]
css history list online [x]
Add warning email for not booking in. [x]
Throttel streaming output. [x]

### Chat

Initial message ✅
Notify admins of when a user messages ✅
Users should be notified of new messages from other participants ✅
New messages should go in the sub menu under Chat. ✅
Handle message seen ✅
Test works for Anonymous users ✅

### 2026-02-18

training_where_time ovewrite price ✅
Add attendee limit. ✅
- Test with training auto creation ✅
- Live update ✅
- Refetch upon data changing ✅
- Test login with qr/nfc code ✅
Exempt membership count when calculating if user has become full member ✅
Show user their membership status. ✅
Better nfc/qrcode trainings on same day attendance resolution. ✅
Create page for lidia.

### Venue tracking

Venues should have configerable options, None, Bill per antendee, Bill per hour. ✅
Configuration config should be stored in the venue table as jsonb ✅
Gocardless link

Trainings will have a toggle for if billing is enabled ✅
You should be able to override Venue billing option. ✅
Training will have an override amount. This is now the Fixed option ✅

Validate per_hour that start_time and end_time are set. ✅

TrainingForm: if per_hour, start_time and end time are required, unless override is set. ✅
Venue form: All end times should be set if per_hour ✅

Time fields should still be displayed in comittment mode if venue billing is enabled and billing is per_hour. ✅

Transactions directly link to a venue via join table ✅

Show a venues accounts

Add into the Annual report

Test reccuring training creation ✅


Make gocardless link table. ✅
- test registration ✅
- venue gocardless ✅

Loads of queries when opening a transaction page ✅
Validate Transactions can't have training_where_id and who_member_id both set. ✅

Credits Menue
