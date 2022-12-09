
Analysis line 

select all tokens which have 

A token that has not expired and has not been used

Current liabilities

SELECT * from tokens where 
(tokens.transaction not null && tokens.transaction.when < now)
or (tokens.transaction is null and tokens.inserted_at < now)
tokens.used_on >= now and tokens.expires >= now

Then select all future tokens, walk over day by day



```
SELECT sum(t0."value") FROM "tokens" AS t0
LEFT OUTER JOIN "transactions" AS t1 ON t1."id" = t0."transaction_id"
WHERE ((((t0."expires_on" > "2022-11-29") AND
  ((t0."used_on" > "2022-11-29") OR (t0."used_on" IS NULL)))
  AND ((NOT (t1."id" IS NULL) AND (t1."when" <= "2022-11-29")))
    OR ((t1."id" IS NULL) AND (t0."inserted_at" < "2022-11-30T00:00:00"))))
```

```
SELECT sum(t0."value") FROM "tokens" AS t0
LEFT OUTER JOIN "transactions" AS t1 ON t1."id" = t0."transaction_id"
WHERE (t0."expires_on" > "2022-11-29")
	AND ((t0."used_on" > "2022-11-29") OR (t0."used_on" IS NULL))
  AND (((NOT (t1."id" IS NULL) AND (t1."when" <= "2022-11-29")))
    OR ((t1."id" IS NULL) AND (t0."inserted_at" < "2022-11-30T00:00:00")))
```