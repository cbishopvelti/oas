import { useQuery, gql } from "@apollo/client";
import { IconButton, Table, TableBody, TableCell, TableContainer, TableHead, TableRow } from "@mui/material";
import { useEffect } from "react";
import { get } from 'lodash';
import EditIcon from '@mui/icons-material/Edit';
import { Link, useParams } from 'react-router-dom';
import CardMembershipIcon from '@mui/icons-material/CardMembership';

export const MembershipPeriodsDisplay = ({
  membershipPeriods,
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
          {membershipPeriods.map((membershipPeriod) => 
            <TableRow key={membershipPeriod.id}>
              <TableCell>{membershipPeriod.id}</TableCell>
              <TableCell>{membershipPeriod.name}</TableCell>
              <TableCell>{membershipPeriod.from}</TableCell>
              <TableCell>{membershipPeriod.to}</TableCell>
              <TableCell>{membershipPeriod.value}</TableCell>
              <TableCell>
                <IconButton component={Link} to={`/membership-period/${membershipPeriod.id}/members`}>
                  <CardMembershipIcon />
                </IconButton>
                <IconButton component={Link} to={`/membership-period/${membershipPeriod.id}`}>
                  <EditIcon />
                </IconButton>
                {ExtraActions && <ExtraActions membership_period_id={membershipPeriod.id} membership_period_members={membershipPeriod.members} />}
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>
    </TableContainer>
  </div>)
}