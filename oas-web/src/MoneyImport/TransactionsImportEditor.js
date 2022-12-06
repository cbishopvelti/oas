import { useEffect, useState } from "react"
import {
  Box,
  FormControl,
  FormControlLabel,
  Button,
  Stack,
  Alert,
  InputLabel,
  Input,
  Table,
  TableContainer,
  TableHead,
  TableBody,
  TableRow,
  TableCell,
  Switch
} from '@mui/material'
import { styled } from '@mui/material/styles';
import { filter, get, toPairs, map } from 'lodash'
import { useMutation, gql } from "@apollo/client"
import { TransactionsImportRow } from "./TransactionsImportRow";


export const TransactionsImportEditor = ({
  transactions_import,
  refetch,
  transactionTags
}) => {
  // const [formData, setFormData] = useState()
  // const [transactionTags, setTransactionTags] = useState([])
  // useState(() => {
  //   const initState = transactions_import.reduce((acc, row, i) => {
  //     let out = false;
  //     if (!row.errors && !row.warnings) {
  //       out = true;
  //     }
  //     return {
  //       ...acc,
  //       [i]: {
  //         toImport: out,
  //         transaction_tags: [{
  //           name: row.subcategory
  //         }]
  //       }
  //     }
  //   }, {})

  //   setFormData(initState);
  // }, [])

  const [reprocess] = useMutation(gql`
    mutation {
      import_transactions_reprocess {
        success
      }
    }
  `)
  useEffect(() => {
    reprocess().then(
      () => {
        refetch()
      }
    )
  }, [])

  const [mutation] = useMutation(gql`
    mutation  {
      do_import_transactions {
        success
      }
    }
  `)
  
  const save = () => async () => {

    await mutation();

    refetch();
  }

  
  return <>
    <TableContainer>
      <Table>
        <TableHead>
          <TableRow>
            <TableCell>Date</TableCell>
            <TableCell>Who</TableCell>
            {/* <TableCell>Who Member</TableCell> */}
            <TableCell>State</TableCell>
            <TableCell>What</TableCell>
            <TableCell>Tags</TableCell>
            <TableCell>Amount</TableCell>
            <TableCell>Import</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {transactions_import.map((row, i) => {
            // formData={formData}
            // setFormData={setFormData}
            return <TransactionsImportRow key={i} row={row} i={i}
              transactionTags={transactionTags}
              refetch={refetch}
            />
          })}
        </TableBody>
      </Table>
    </TableContainer>
    <FormControl fullWidth sx={{m:2}}>
      <Button onClick={save()}>Do Import</Button>
    </FormControl>
  </>

}