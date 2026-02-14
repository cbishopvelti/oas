
Venues should have configerable options, None, Bill per antendee, Bill per hour. ✅
Configuration config should be stored in the venue table as jsonb ✅
Gocardless link

Trainings will have a toggle for if billing is enabled ✅
You should be able to override Venue billing option. ✅
Training will have an override amount ✅

Validate per_hour that start_time and end_time are set.

TrainingForm: if per_hour, start_time and end time are required, unless override is set.
Venue form: All end times should be set if per_hour

Time fields should still be displayed in comittment mode if venue billing is enabled, override is not set and billing_type is per_hour.

Transactions directly link to a venue via join table

The Venue running account should be generated upon request.

Add into the Annual report

Test reccuring training creation

Add a table to show transactions against a venue

Make gocardless link table.

### Continue
to write training_billing_amount graphql
