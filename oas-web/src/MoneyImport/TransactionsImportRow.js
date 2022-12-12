import { useState } from "react"
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
  Switch,
  Collapse,
  IconButton
} from '@mui/material'
import { styled } from '@mui/material/styles';
import KeyboardArrowDownIcon from '@mui/icons-material/KeyboardArrowDown';
import KeyboardArrowUpIcon from '@mui/icons-material/KeyboardArrowUp';
import { filter, get, toPairs, map, set } from 'lodash'
import { NavLink } from 'react-router-dom'
import { TransactionTags } from "../Money/TransactionTags";
import { StyledTableRow } from '../utils/util'
import { gql, useMutation } from "@apollo/client";

export const TransactionsImportRow = ({
  row,
  i,
  setFormData,
  formData,
  transactionTags,
  refetch
}) => {
  const [open, setOpen] = useState(false);

  const [toImportMutation] = useMutation(gql`
    mutation ($index: Int!, $to_import: Boolean!) {
      set_to_import(index: $index, to_import: $to_import) {
        success
      }
    }
  `)

  const [tagsMutation] = useMutation(gql`
    mutation ($index: Int!, $tags: [String]!) {
      set_tags(index: $index, tags: $tags) {
        success
      }
    }
  `)
  

  return <>
      <StyledTableRow className={`${row.errors && 'errors'} ${row.warnings && 'warnings'}`} key={i}>
        <TableCell>
          {row.date}
        </TableCell>
        <TableCell title={(!row.member?.name) ? "Member not found" : null} sx={(theme) => ({
          ...(!row.member?.name ? {backgroundColor: theme.palette.warning.main } : {} )
        })}>
          {row.member?.name || row.bank_account_name}
        </TableCell>
        <TableCell>
          {row.state}
        </TableCell>
        <TableCell>
          {row.my_reference}
        </TableCell>
        <TableCell>
          <TransactionTags
            transactionTags={transactionTags.map((tag) => ({name: tag}))}
            formData={{
              transaction_tags: get(row, "tags", []).map((tag) => ({name: tag}))
            }}
            setFormData={async ({transaction_tags}) => {
              await tagsMutation({variables: {
                index: i,
                tags: transaction_tags.map(({name}) => name)
              }});
              refetch();
            }}
          />
        </TableCell>
        <TableCell>
          {row.amount}
        </TableCell>
        <TableCell>
            <Switch 
              disabled={!!row.errors}
              checked={row.to_import || false}
              onChange={async (event) => {
                await toImportMutation({
                  variables: {
                    index: i,
                    to_import: event.target.checked
                  }
                });
                refetch();
                //  setFormData({
                //   ...formData,
                //   [i]: {
                //     ...get(formData, [i], {}),
                //     toImport: event.target.checked
                //   }
                // })
              }}/>

            {(row.errors || row.warnings) && <IconButton
              aria-label="expand row"
              size="small"
              onClick={() => setOpen(!open)}
            >
              {open ? <KeyboardArrowUpIcon /> : <KeyboardArrowDownIcon />}
            </IconButton>}
        </TableCell>
      </StyledTableRow>
      {(row.errors || row.warnings) && 
        <StyledTableRow className={`${row.errors && 'errors'} ${row.warnings && 'warnings'}`}>
          <TableCell style={{ paddingBottom: 0, paddingTop: 0 }} colSpan={7}>
            <Collapse in={open} timeout="auto" unmountOnExit>
              <Stack sx={{ width: '100%' }}>
                {row.errors?.map((item, i) => (
                  <Alert key={i} sx={{m:1}} severity="error">
                    {item.name}{item.transaction_id && <> of <NavLink to={`/transaction/${item.transaction_id}`}>/transaction/{item.transaction_id}</NavLink></>}
                  </Alert>
                ))}

                {row.warnings?.map((item, i) => (
                  <Alert key={i} sx={{m:1}} severity="warning">
                    {item}
                  </Alert>
                ))}
              </Stack>
            </Collapse>
          </TableCell>
        </StyledTableRow>}
    </>

}