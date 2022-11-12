import { gql, useQuery, useMutation } from "@apollo/client"
import { MembersDisplay } from "../Member/MembersDisplay"
import { IconButton
 } from "@mui/material";
import { get } from 'lodash';
import { useParams, useOutletContext } from "react-router-dom";
import { useEffect } from "react";
import DeleteIcon from '@mui/icons-material/Delete';


export const DeleteMembership = ({membership_period_id, refetch}) => {
  const [mutation] = useMutation(gql`
    mutation ($member_id: Int!, $membership_period_id: Int!) {
      delete_membership(member_id: $member_id, membership_period_id: $membership_period_id) {
        success
      }
    }
  `);

  if (!membership_period_id) {
    return <></>
  }

  return ({member_id}) => {

    return <IconButton title={`Delete this members membership`} onClick={async () => {
      await mutation({
        variables: {
          membership_period_id,
          member_id
        }
      })
      refetch()
    }}>
      <DeleteIcon sx={{color: 'red'}} />
    </IconButton>
  }
}


export const MembershipPeriodMembers = () => {
  const { setTitle } = useOutletContext();

  let { id } = useParams();
  id = parseInt(id);

  useEffect(() => {
    setTitle("Membership Periods's Members");
  }, [])

  const {data, refetch} = useQuery(gql`
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

  return <MembersDisplay members={members} ExtraActions={DeleteMembership({membership_period_id: id, refetch})}/>
}
