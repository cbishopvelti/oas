import { useQuery, gql } from "@apollo/client";
import { IconButton, Table, TableBody, TableCell, TableContainer, TableHead, TableRow } from "@mui/material";
import { useEffect } from "react";
import { get } from 'lodash';
import EditIcon from '@mui/icons-material/Edit';
import { Link, useParams, useOutletContext } from 'react-router-dom';
import { MembershipPeriodsDisplay } from "./MembershipPeriodsDisplay";

export const MembershipPeriods = () => {
  const { setTitle } = useOutletContext();

  const { data, refetch } = useQuery(gql`
    query {
      membership_periods {
        id,
        name,
        from,
        to,
        value
      }
    }
  `)



  useEffect(() => {
    setTitle("Membership Periods");
    refetch();
  }, []);

  let membershipPeriods = get(data, 'membership_periods', []);

  return (<MembershipPeriodsDisplay membershipPeriods={membershipPeriods} />)
}