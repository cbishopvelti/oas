import { gql, useQuery } from "@apollo/client"
import { MembersDisplay } from "../Member/MembersDisplay"
import { get } from 'lodash';
import { useParams, useOutletContext } from "react-router-dom";
import { useEffect } from "react";





export const MembershipPeriodMembers = () => {
  const { setTitle } = useOutletContext();

  let { id } = useParams();
  id = parseInt(id);

  useEffect(() => {
    setTitle("Membership Periods's Members");
  }, [])

  const {data} = useQuery(gql`
    query ($id: Int!) {
      membership_period(id: $id) {
        members {
          id,
          name,
          email,
          token_count
        }
      }
    }
  `, {
    variables: {
      id
    }
  })

  const members = get(data, 'membership_period.members', [])

  return <MembersDisplay members={members}/>
}
