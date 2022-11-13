import { gql, useQuery, useMutation } from "@apollo/client"
import { MembersDisplay } from "../Member/MembersDisplay"
import { IconButton
 } from "@mui/material";
import { get } from 'lodash';
import { useParams, useOutletContext, Link } from "react-router-dom";
import { useEffect } from "react";
import DeleteIcon from '@mui/icons-material/Delete';
import PaidIcon from '@mui/icons-material/Paid';


export const DeleteMembership = ({membership_period_id, membership_period_name, refetch}) => {
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

  return ({member_id, data}) => {

    console.log("006", data);

    return <>
      {data.transaction && <IconButton title={`Go to ${membership_period_name}'s transaction`} component={Link} to={`/transaction/${data.transaction.id}`}>
        <PaidIcon />
      </IconButton>}
      <IconButton title={`Delete ${data.member.name}'s membership`} onClick={async () => {
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
      
    </>
  }
}


export const MembershipPeriodMembers = () => {
  const { setTitle } = useOutletContext();

  let { id } = useParams();
  id = parseInt(id);

  

  const {data, refetch} = useQuery(gql`
    query ($id: Int!) {
      membership_period(id: $id) {
        name
        memberships {
          id,
          transaction {
            id
          }
          member {
            id,
            name,
            email,
            token_count
          }
        }
      }
    }
  `, {
    variables: {
      id
    }
  })

  useEffect(() => {
    setTitle(`Membership Period: ${get(data, 'membership_period.name', id)}'s Members`);
  }, [get(data, 'membership_period.name')])

  const memberships = get(data, 'membership_period.memberships', [])

  return <MembersDisplay data={memberships} dataKey={`member`} ExtraActions={DeleteMembership({membership_period_id: id, membership_period_name: get(data, 'membership_period.name', id), refetch})}/>
}
