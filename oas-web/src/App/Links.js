import { find, includes, some } from "lodash"
import React from "react"
import { NavLink, useMatches, useParams } from "react-router-dom"

export const CustomLink = (ids) => React.forwardRef((params, ref) => {
  const matches = useMatches()

  let isActive = false;
  isActive =
    some(matches, ({id}) => includes(ids, id))

  return <NavLink
    {...params}
    ref={ref}
    className={`${params.className} ${isActive ? 'active': ''}`}
  />
})

export const MemberLink = React.forwardRef((params, ref) => {
  const matches = useMatches()

  let isActive = false;
  isActive =
    some(matches, ({id}) => includes(["members", "member-tokens", "member-id", "member-membership-periods", "member-transactions", "membership-period-members"], id))

  return <NavLink
    {...params}
    ref={ref}
    className={`${params.className} ${isActive ? 'active': ''}`}
  />
})

export const TrainingsLink = React.forwardRef((params, ref) => {
  const matches = useMatches()

  let isActive = false;
  isActive =
    some(matches, ({id}) => includes(["training-id", "trainings"], id))


  return <NavLink
    {...params}
    ref={ref}
    className={`${params.className} ${isActive ? 'active': ''}`}
  />
})

export const TransactionLink = React.forwardRef((params, ref) => {
  const matches = useMatches()

  let isActive = false;
  isActive =
    some(matches, ({id}) => includes(["transaction-id", "transactions", "member-transactions"], id))


  return <NavLink
    {...params}
    ref={ref}
    className={`${params.className} ${isActive ? 'active': ''}`}
  />
})
export const MembershipPeriodLink = React.forwardRef((params, ref) => {
  const matches = useMatches()

  let isActive = false;
  isActive =
    some(matches, ({id}) => includes(["membership-period-id", "membership-periods", "membership-period-members", "member-membership-periods"], id))


  return <NavLink
    {...params}
    ref={ref}
    className={`${params.className} ${isActive ? 'active': ''}`}
  />
})

