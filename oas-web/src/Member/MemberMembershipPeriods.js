import { useQuery, gql, useMutation } from "@apollo/client";
import { IconButton, Table, TableBody, TableCell, TableContainer, TableHead, TableRow } from "@mui/material";
import { useEffect } from "react";
import { get } from 'lodash';
import EditIcon from '@mui/icons-material/Edit';
import { Link, useParams, useOutletContext } from 'react-router-dom';
import { MembershipPeriodsDisplay } from "../MembershipPeriod/MembershipPeriodsDisplay";
import DeleteIcon from '@mui/icons-material/Delete';

export const DeleteMembership = ({member_id, refetch}) => {
  const [mutation] = useMutation(gql`
    mutation ($member_id: Int!, $membership_period_id: Int!) {
      delete_membership(member_id: $member_id, membership_period_id: $membership_period_id) {
        success
      }
    }
  `);
  return ({membership_period_id}) => {

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

export const MemberMembershipPeriods = () => {
  const { setTitle } = useOutletContext();

  let {member_id} = useParams()
  member_id = parseInt(member_id)

  const { data, refetch } = useQuery(gql`
    query($member_id: Int!) {
      member(member_id: $member_id) {
        membership_periods {
          id,
          name,
          from,
          to,
          value
        }
      }
    }
  `, {
    variables: {
      member_id
    }
  })

  useEffect(() => {
    setTitle("Member's Memberships");
    refetch();
  }, []);

  let membershipPeriods = get(data, 'member.membership_periods', []);

  return (<MembershipPeriodsDisplay
    membershipPeriods={membershipPeriods}
    ExtraActions={DeleteMembership({member_id, refetch})}
    />)
}