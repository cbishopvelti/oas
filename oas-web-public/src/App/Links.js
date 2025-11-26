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
