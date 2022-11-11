# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
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
  email: "chrisjbishop155@hotmail.com",
  name: "Chris Bishop",
  hashed_password: "$2b$12$lLv5qfJjouSBF4FqDXozuuuGULgN9awWYNcyP/VjobgnqzFBYpwei",
  is_admin: true,
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 3)
})

Oas.Repo.insert!(%Oas.Members.Member{
  email: "anne.hedegaard@hotmail.com",
  name: "Anne Hedegaard",
  hashed_password: "$2b$12$5tshFTMLkU39cAHh9weY2uWGcb89k5jdEWdkBmTrOhiwf6c8AySKK",
  is_admin: true,
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 8)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "viktoria.trautner@gmail.com",
  name: "Viktoria Trautner",
  hashed_password: "$2b$12$/YTONeCfQLuBSgYIMAcKXuZ4uCycJj.CODkVbFGATwPX9eNDlCRiW",
  is_admin: true,
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 8)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "benmartin@doctors.org.uk",
  name: "Benjamin Martin",
  hashed_password: "$2b$12$sWUsBmHJejQQXFKVvIyJ/OKp6IIkKcS6f/Q849IXXFZKBDgYpZ1H6",
  is_admin: true,
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 13)
})

Oas.Repo.insert!(%Oas.Members.Member{
  email: "annika.rings@freenet.de",
  name: "Annika Rings",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 1)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "ben@britishacrobatics.org",
  name: "Ben Keitch",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  is_reviewer: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 4)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "chloebruyas@yahoo.fr",
  name: "Chloe Bruyas",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 0)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "dariajensen@gmail.com",
  name: "Daria Jensen",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 0)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "elizabethangelajohnson@gmail.com",
  name: "Elizabeth Johnson",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 0)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "farbless@gmail.com",
  name: "Elizaveta Semenova",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 4)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "francescaleiper@hotmail.com",
  name: "Francesca Leiper",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 8)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "irene.torreggiani4@gmail.com",
  name: "Irene Torreggiani",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 0)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "isabelcmms@gmail.com",
  name: "Isabel Silva",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 2)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "jakub.hajko@gmail.com",
  name: "Jakub Hajko",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 6)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "lidkaoz@gmail.com",
  name: "Lidia Ozarowska",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 1)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "momentblur@gmail.com",
  name: "Luke Mcconkey",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 0)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "mnwebb@outlook.com",
  name: "Matthew Webb",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 8)
})
# Oas.Repo.insert!(%Oas.Members.Member{
#   email: "",
#   name: "Philip Mousley",
#   hashed_password: "abcdefghijklmnopqrstuvwxyz",
#   is_active: true,
#   membership_periods: [membershipPeriod],
#   tokens: List.duplicate(token, 0)
# })
Oas.Repo.insert!(%Oas.Members.Member{
  email: "rhodri.buttrick@gmail.com",
  name: "Rhodri Buttrick",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 6)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "ricardo.de.carvalho@outlook.com",
  name: "Ricardo de Cavalho",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 7)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "sjefbaas@me.com",
  name: "Sjef Baas",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  is_admin: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 10)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "Williamtorforbes@gmail.com",
  name: "William Forbes",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 0)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "will_henderson@hotmail.co.uk",
  name: "William Henderson",
  hashed_password: "abcdefghijklmnopqrstuvwxyz",
  is_active: true,
  membership_periods: [membershipPeriod],
  tokens: List.duplicate(token, 0)
})
Oas.Repo.insert!(%Oas.Members.Member{
  email: "winok_14@hotmail.com",
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
