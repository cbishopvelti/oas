# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds_fake.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Oas.Repo.insert!(%Oas.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

Oas.Repo.delete_all(Oas.Members.Membership)
Oas.Repo.delete_all(Oas.Members.MembershipPeriod)
Oas.Repo.delete_all(Oas.Transactions.Transaction)
Oas.Repo.delete_all(Oas.Tokens.Token)
Oas.Repo.delete_all(Oas.Members.MemberDetails)
Oas.Repo.delete_all(Oas.Trainings.Attendance)
Oas.Repo.delete_all(Oas.Members.Member)

membershipPeriod = Oas.Repo.insert!(%Oas.Members.MembershipPeriod{
  name: "2022-2023",
  from: ~D[2022-11-01],
  to: ~D[2023-10-31],
  value: 6
})

token = %Oas.Tokens.Token{
  expires_on: Date.add(Date.utc_today(), 365),
  value: 4.5
}

Oas.Repo.insert!(%Oas.Members.Member{
  email: "chrisjbishop155@hotmail.com"
  name: "Chris Bishop",
  hashed_password: "$2b$12$lLv5qfJjouSBF4FqDXozuuuGULgN9awWYNcyP/VjobgnqzFBYpwei",
  is_admin: true,
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 3)
})

Oas.Repo.insert!(%Oas.Members.Member{
  email: "test1@test.com"
  name: "Anne Hedegaard",
  hashed_password: "$2b$12$5tshFTMLkU39cAHh9weY2uWGcb89k5jdEWdkBmTrOhiwf6c8AySKK",
  is_admin: true,
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 8)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "test2@test.com"
  name: "Viktoria Trautner",
  hashed_password: "$2b$12$/YTONeCfQLuBSgYIMAcKXuZ4uCycJj.CODkVbFGATwPX9eNDlCRiW",
  is_admin: true,
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 8)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "test3@test.com"
  name: "Benjamin Martin",
  hashed_password: "$2b$12$sWUsBmHJejQQXFKVvIyJ/OKp6IIkKcS6f/Q849IXXFZKBDgYpZ1H6",
  is_admin: true,
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 13)
})

Oas.Repo.insert!(%Oas.Members.Member{
  email: "test4@test.com"
  name: "Annika Rings",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 1)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "test5@test.com"
  name: "Ben Keitch",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  is_reviewer: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 4)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "test6@test.com"
  name: "Chloe Bruyas",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 0)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "test7@test.com"
  name: "Daria Jensen",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 0)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "test8@test.com"
  name: "Elizabeth Johnson",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 0)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "test9@test.com"
  name: "Elizaveta Semenova",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 4)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "test10@test.com"
  name: "Francesca Leiper",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 8)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "test11@test.com"
  name: "Irene Torreggiani",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 0)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "test12@test.com"
  name: "Isabel Silva",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 2)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "test13@test.com"
  name: "Jakub Hajko",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 6)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "test14@test.com"
  name: "Lidia Ozarowska",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 1)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "test15@test.com"
  name: "Luke Mcconkey",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 0)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "test16@test.com"
  name: "Matthew Webb",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 8)
})
# Oas.Repo.insert!(%Oas.Members.Member{
#   email: "test@test.com"
#   name: "Philip Mousley",
#   hashed_password: "abcdefghijklmnopqrstuvwxyz",
#   is_active: true,
#   membership_periods: [membershipPeriod],
#   tokens: List.duplicate(token, 0)
# })
Oas.Repo.insert!(%Oas.Members.Member{
  email: "test17@test.com"
  name: "Rhodri Buttrick",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 6)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "test18@test.com"
  name: "Ricardo de Cavalho",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 7)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "test19@test.com"
  name: "Sjef Baas",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  is_admin: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 10)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "test20@test.com"
  name: "William Forbes",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 0)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "test21@test.com"
  name: "William Henderson",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 0)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "test22@test.com"
  name: "Winok Lapidaire",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 0)
})

Oas.Repo.insert(%Oas.Transactions.Transaction{
  what: "From old spreadsheets",
  who: "old spreadsheets",
  my_reference: "old spreadsheets",
  type: "INCOMING",
  when: Date.utc_today(),
  amount: 1_453.96,
  not_transaction: true
})
