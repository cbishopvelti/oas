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


export const TransactionsImportEditor = ({transactions_import, refetch}) => {
  const [formData, setFormData] = useState()
  useState(() => {
    const initState = transactions_import.reduce((acc, row, i) => {
      let out = false;
      if (!row.errors && !row.warnings) {
        out = true;
      }
      return {
        ...acc,
        [i]: out
      }
    }, {})

    setFormData(initState);
  }, [])
  

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
    mutation ($indexes_to_import: [Int]!) {
      do_import_transactions (indexes_to_import: $indexes_to_import) {
        success
      }
    }
  `)
  
  const save = (formData) => async () => {
    let formDataArray = toPairs(formData)
    formDataArray = filter(formDataArray, ([id, toImport]) => toImport)
    formDataArray = map(formDataArray, ([id, toImport]) => parseInt(id))

    await mutation({
      variables: {
        indexes_to_import: formDataArray
      }
    })

    refetch()
  }

  
  return <>
    <TableContainer>
      <Table>
        <TableHead>
          <TableRow>
            <TableCell>Date</TableCell>
            <TableCell>Who</TableCell>
            <TableCell>Who Member</TableCell>
            <TableCell>State</TableCell>
            <TableCell>What</TableCell>
            <TableCell>Amount</TableCell>
            <TableCell>Import</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {transactions_import.map((row, i) => {
            return <TransactionsImportRow key={i} row={row} i={i} formData={formData} setFormData={setFormData} />
          })}
        </TableBody>
      </Table>
    </TableContainer>
    <FormControl fullWidth sx={{m:2}}>
      <Button onClick={save(formData)}>Do Import</Button>
    </FormControl>
  </>

}