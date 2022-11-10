import { useQuery, gql } from "@apollo/client";
import { IconButton, Table, TableBody, TableCell, TableContainer, TableHead, TableRow } from "@mui/material";
import { useEffect } from "react";
import { get } from 'lodash';
import EditIcon from '@mui/icons-material/Edit';
import { Link, useParams, useOutletContext } from 'react-router-dom';
import { MembershipPeriodsDisplay } from "../MembershipPeriod/MembershipPeriodsDisplay";

export const MemberMembershipPeriods = () => {
  const { setTitle } = useOutletContext();
  setTitle("Member's Memberships");

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
    refetch();
  }, []);

  let membershipPeriods = get(data, 'member.membership_periods', []);

  return (<MembershipPeriodsDisplay membershipPeriods={membershipPeriods} />)
}