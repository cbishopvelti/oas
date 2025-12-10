import { useQuery, gql, useSubscription } from "@apollo/client";
import { useEffect } from "react";
import { useOutletContext } from "react-router-dom";
import { get } from 'lodash'
import { GocardlessImportCountdown } from './Transactions';
import { Table, TableBody, TableCell, TableContainer, TableHead, TableRow } from "@mui/material";

export const PendingTransactions = () => {
  const { setTitle, setComponents } = useOutletContext();

  const { data, refetch } = useQuery(gql`
    query {
      pending_transactions {
        booking_date,
        remittance_information_unstructured,
        amount
      }
      gocardless_trans_status {
        next_run
      }
    }
  `)

  useEffect(() => {
    setTitle("Pending transactions")
    if (get(data, "gocardless_trans_status.next_run")) {
      setComponents([GocardlessImportCountdown(data)])
    }
  }, [])

  useSubscription(gql`
    subscription {
      gocardless_trans_status {
        success
      }
    }
  `, {
    onData() {
      refetch()
    }
  })

  return <TableContainer>
    <Table>
      <TableHead>
        <TableRow>
          <TableCell>when</TableCell>
          <TableCell>Remittance Information</TableCell>
          <TableCell>Amount</TableCell>
        </TableRow>
      </TableHead>
      <TableBody>
        {get(data, "pending_transactions", []).map((data) => {
          return <TableRow>
            <TableCell>{data.booking_date}</TableCell>
            <TableCell>{data.remittance_information_unstructured}</TableCell>
            <TableCell>{data.amount}</TableCell>
          </TableRow>
        })}
      </TableBody>
    </Table>
  </TableContainer>
}
