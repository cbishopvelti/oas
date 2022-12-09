
Analysis line 

select all tokens which have 

A token that has not expired and has not been used

Current liabilities

SELECT * from tokens where 
(tokens.transaction not null && tokens.transaction.when < now)
or (tokens.transaction is null and tokens.inserted_at < now)
tokens.used_on >= now and tokens.expires >= now

Then select all future tokens, walk over day by day

