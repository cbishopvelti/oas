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

export const TransactionsImportRow = ({
  row,
  i,
  setFormData,
  formData
}) => {
  const [open, setOpen] = useState(false);

  

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
            formData={get(formData, [i], [])}
            setFormData={({transaction_tags}) => {
              setFormData({
                ...formData,
                [i]: {
                  ...get(formData, [i], {}),
                  transaction_tags: transaction_tags
                }
              })
            }}
          />
        </TableCell>
        <TableCell>
          {row.amount}
        </TableCell>
        <TableCell>
            <Switch 
              disabled={!!row.errors}
              checked={get(formData, [i, 'toImport'], false) || false}
              onChange={(event) => setFormData({
                ...formData,
                [i]: {
                  ...get(formData, [i], {}),
                  toImport: event.target.checked
                }
              })}/>

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
                    {item.name}{item.transaction_id && <>&nbsp;<NavLink to={`/transaction/${item.transaction_id}`}>transaction/{item.transaction_id}</NavLink> </>}
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