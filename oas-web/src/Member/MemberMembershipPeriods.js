import { useQuery, gql, useMutation } from "@apollo/client";
import { IconButton, Table, TableBody, TableCell, TableContainer, TableHead, TableRow } from "@mui/material";
import { useEffect } from "react";
import { get } from 'lodash';
import EditIcon from '@mui/icons-material/Edit';
import { Link, useParams, useOutletContext } from 'react-router-dom';
import { MembershipPeriodsDisplay } from "../MembershipPeriod/MembershipPeriodsDisplay";
import DeleteIcon from '@mui/icons-material/Delete';
import PaidIcon from '@mui/icons-material/Paid';

export const DeleteMembership = ({member_id, refetch}) => {
  const [mutation] = useMutation(gql`
    mutation ($member_id: Int!, $membership_period_id: Int!) {
      delete_membership(member_id: $member_id, membership_period_id: $membership_period_id) {
        success
      }
    }
  `);
  return ({membership_period_id, data}) => {

    return <>
      {data.transaction && <IconButton title="Go to the transaction" component={Link} to={`/transaction/${data.transaction.id}`}>
        <PaidIcon />
      </IconButton>}
      <IconButton title={`Delete this members membership`} onClick={async () => {
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

export const MemberMembershipPeriods = () => {
  const { setTitle } = useOutletContext();

  let {member_id} = useParams()
  member_id = parseInt(member_id)

  const { data, refetch } = useQuery(gql`
    query($member_id: Int!) {
      member(member_id: $member_id) {
        name
        memberships {
          id
          transaction {
            id
          }
          membership_period {
            id,
            name,
            from,
            to,
            value
          }
        }
      }
    }
  `, {
    variables: {
      member_id
    }
  })
  useEffect(() => {
    refetch();
  }, [])

  useEffect(() => {
    setTitle(`Member: ${get(data, 'member.name', member_id)}'s Memberships`);
  }, [get(data, 'member.name')]);

  return (<MembershipPeriodsDisplay
    data={get(data, 'member.memberships', [])}
    dataKey={'membership_period'}
    ExtraActions={DeleteMembership({member_id, refetch})}
    />)
}