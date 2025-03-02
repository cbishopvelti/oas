import { useEffect } from "react";
import { useQuery, gql } from "@apollo/client";
import { Link } from 'react-router-dom';
import { get } from 'lodash';
import {
  Table,
  TableContainer,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  IconButton,
  Box
} from '@mui/material';
import PaidIcon from '@mui/icons-material/Paid';

export const Credits = ({
  member_id,
  refetch: parentRefetch = () => {}
}) => {

  // attendance {
  //   training {
  //     id
  //   }
  // }
  // transaction {
  //   id,
  //   when
  // }
  const { data, refetch } = useQuery(gql`
    query ($member_id: Int) {
      credits(member_id: $member_id) {
        id,
        expires_on,
        who_member_id,
        amount,
        when,
        what,
        after_amount,
        transaction {
          id
        }
      }
    }
  `, {
    variables: {
      ...(member_id ? {member_id: member_id} : {} )
    }
  })

  useEffect(() => {
    refetch();
  }, [])

  const credits = get(data, "credits", []);

  return <div>
    <TableContainer>
      <Table>
        <TableHead>
          <TableRow>
            <TableCell>Id</TableCell>
            <TableCell>What</TableCell>
            <TableCell>When</TableCell>
            <TableCell>Expires on</TableCell>
            <TableCell>Amount</TableCell>
            <TableCell>Cumulating</TableCell>
            <TableCell>Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {credits.map((credit, i) => {
            return <TableRow key={i}>
              <TableCell>{credit.id}</TableCell>
              <TableCell>{credit.what}</TableCell>
              <TableCell>{credit.when}</TableCell>
              <TableCell>{credit.expires_on}</TableCell>
              <TableCell>{credit.amount}</TableCell>
              <TableCell>{credit.after_amount}</TableCell>
              <TableCell>
                {credit?.transaction?.id &&
                  <IconButton
                    title="Go to transaction"
                    component={Link}
                    to={`/transaction/${credit.transaction.id}`}>
                    <PaidIcon />
                  </IconButton>
                }
              </TableCell>
            </TableRow>
          })}
        </TableBody>
      </Table>
    </TableContainer>
  </div>
}
