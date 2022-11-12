import { useQuery, gql, useMutation } from "@apollo/client";
import { IconButton, Table, TableBody, TableCell, TableContainer, TableHead, TableRow } from "@mui/material";
import { useEffect } from "react";
import { get } from 'lodash';
import EditIcon from '@mui/icons-material/Edit';
import { Link, useParams, useOutletContext } from 'react-router-dom';
import { MembershipPeriodsDisplay } from "./MembershipPeriodsDisplay";
import DeleteIcon from '@mui/icons-material/Delete';

export const DeleteMembershipPeriod = ({ refetch }) => {
  const [mutation] = useMutation(gql`
    mutation ($membership_period_id: Int!) {
      delete_membership_period(membership_period_id: $membership_period_id) {
        success
      }
    }
  `);
  return ({membership_period_id, membership_period_members}) => {
    if (membership_period_members && membership_period_members.length !== 0) {
      return <></>
    }

    return <IconButton title={`Delete this membership period`} onClick={async () => {
      await mutation({
        variables: {
          membership_period_id,
        }
      })
      refetch()
    }}>
      <DeleteIcon sx={{color: 'red'}} />
    </IconButton>
  }
}

export const MembershipPeriods = () => {
  const { setTitle } = useOutletContext();

  const { data, refetch } = useQuery(gql`
    query {
      membership_periods {
        id,
        name,
        from,
        to,
        value,
        members {
          id
        }
      }
    }
  `)



  useEffect(() => {
    setTitle("Membership Periods");
    refetch();
  }, []);

  let membershipPeriods = get(data, 'membership_periods', []);

  return (<MembershipPeriodsDisplay
    membershipPeriods={membershipPeriods}
    ExtraActions={DeleteMembershipPeriod({refetch})}
    />)
}