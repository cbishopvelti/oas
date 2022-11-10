import { gql, useQuery } from "@apollo/client"
import { MembersDisplay } from "../Member/MembersDisplay"
import { get } from 'lodash';
import { useParams, useOutletContext } from "react-router-dom";


export const MembershipPeriodMembers = () => {
  const { setTitle } = useOutletContext();
  setTitle("Membership Periods's Members");

  let { id } = useParams();
  id = parseInt(id);

  const {data} = useQuery(gql`
    query ($id: Int!) {
      membership_period(id: $id) {
        members {
          id,
          name,
          email,
          tokens
        }
      }
    }
  `, {
    variables: {
      id
    }
  })

  console.log("009", data);
  const members = get(data, 'membership_period.members', [])

  return <MembersDisplay members={members} />
}
