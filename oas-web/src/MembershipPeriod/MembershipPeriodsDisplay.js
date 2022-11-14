import { useQuery, gql } from "@apollo/client";
import { IconButton, Table, TableBody, TableCell, TableContainer, TableHead, TableRow } from "@mui/material";
import { useEffect } from "react";
import { get } from 'lodash';
import EditIcon from '@mui/icons-material/Edit';
import { Link, useParams } from 'react-router-dom';
import CardMembershipIcon from '@mui/icons-material/CardMembership';
import PeopleIcon from '@mui/icons-material/People';

export const MembershipPeriodsDisplay = ({
  // membershipPeriods,
  data, 
  dataKey,
  ExtraActions
}) => {

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
          {data.map((dat) => {
            const membershipPeriod = dataKey ? get(dat, dataKey) : dat
            return <TableRow key={membershipPeriod.id}>
              <TableCell>{membershipPeriod.id}</TableCell>
              <TableCell>{membershipPeriod.name}</TableCell>
              <TableCell>{membershipPeriod.from}</TableCell>
              <TableCell>{membershipPeriod.to}</TableCell>
              <TableCell>{membershipPeriod.value}</TableCell>
              <TableCell>
                <IconButton component={Link} title={`Go to ${membershipPeriod.name}'s members`} to={`/membership-period/${membershipPeriod.id}/members`}>
                  <PeopleIcon />
                </IconButton>
                <IconButton component={Link} title={`Edit ${membershipPeriod.name}`} to={`/membership-period/${membershipPeriod.id}`}>
                  <EditIcon />
                </IconButton>
                {ExtraActions && <ExtraActions data={dat} membership_period_id={membershipPeriod.id} membership_period_members={membershipPeriod.members} />}
              </TableCell>
            </TableRow>
          })}
        </TableBody>
      </Table>
    </TableContainer>
  </div>)
}