import { gql, useQuery } from '@apollo/client';
import {
  Table,
  TableContainer,
  TableHead,
  TableRow,
  TableCell,
  TableBody
} from '@mui/material';
import { get } from 'lodash';
import { useEffect } from 'react';

export const Transactions = () => {
  
  let { data: transactions, loading, refetch } = useQuery(gql`query {
    transactions {
      id,
      when,
      what,
      who,
      amount
    }
  }`);
  useEffect(() => {
    refetch()
  }, [])
  transactions = get(transactions, "transactions", [])

  return <div>
    <TableContainer>
      <Table>
        <TableHead>
          <TableRow>
            <TableCell>Id</TableCell>
            <TableCell>When</TableCell>
            <TableCell>What</TableCell>
            <TableCell>Who</TableCell>
            <TableCell>Amount</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {
            transactions.map((transaction) => (
              <TableRow key={transaction.id}>
                <TableCell>{transaction.id}</TableCell>
                <TableCell>{transaction.when}</TableCell>
                <TableCell>{transaction.what}</TableCell>
                <TableCell>{transaction.who}</TableCell>
                <TableCell>{transaction.amount}</TableCell>
              </TableRow>
            ))
          }
        </TableBody>
      </Table>
    </TableContainer>
  </div>
}
