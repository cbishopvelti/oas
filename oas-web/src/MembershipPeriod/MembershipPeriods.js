import { useQuery, gql } from "@apollo/client";
import { IconButton, Table, TableBody, TableCell, TableContainer, TableHead, TableRow } from "@mui/material";
import { useEffect } from "react";
import { get } from 'lodash';
import EditIcon from '@mui/icons-material/Edit';
import { Link, useParams } from 'react-router-dom';

export const MembershipPeriods = () => {

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
    refetch();
  }, []);

  let membershipPeriods = get(data, 'membership_periods', []);

  return (<div>
    <TableContainer>
      <Table>
        <TableHead>
          <TableRow>
            <TableCell>Id</TableCell>
            <TableCell>Name</TableCell>
            <TableCell>From</TableCell>
            <TableCell>To</TableCell>
            <TableCell>Value</TableCell>
            <TableCell>Actions</TableCell>
          </TableRow>
        </TableHead>

        <TableBody>
          {membershipPeriods.map((membershipPeriod) => 
            <TableRow key={membershipPeriod.id}>
              <TableCell>{membershipPeriod.id}</TableCell>
              <TableCell>{membershipPeriod.name}</TableCell>
              <TableCell>{membershipPeriod.from}</TableCell>
              <TableCell>{membershipPeriod.to}</TableCell>
              <TableCell>{membershipPeriod.value}</TableCell>
              <TableCell>
                <IconButton component={Link} to={`/membership-period/${membershipPeriod.id}`}>
                  <EditIcon />
                </IconButton>
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>
    </TableContainer>
  </div>)
}