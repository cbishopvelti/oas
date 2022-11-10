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
import { filter, get, toPairs, map } from 'lodash'
import { NavLink } from 'react-router-dom'


export const TransactionsImportRow = ({
  row,
  i,
  setFormData,
  formData
}) => {
  const [open, setOpen] = useState(false);

  const StyledTableRow = styled(TableRow)(({ theme }) => {
    return {
      '&.errors, &.warnings.errors': {
        backgroundColor: theme.palette.error.main
      },
      '&.warnings': {
        backgroundColor: theme.palette.warning.main
      },
      '&.warnings > *, &.errors > *': {
        borderBottom: 'unset'
      }
    }
  });

  return <>
      <StyledTableRow className={`${row.errors && 'errors'} ${row.warnings && 'warnings'}`} key={i}>
        <TableCell>
          {row.date}
        </TableCell>
        <TableCell>
          {row.bank_account_name}
        </TableCell>
        <TableCell>
          {row.member?.name}
        </TableCell>
        <TableCell>
          {row.state}
        </TableCell>
        <TableCell>
          {row.my_reference}
        </TableCell>
        <TableCell>
          {row.amount}
        </TableCell>
        <TableCell>

            <Switch 
              disabled={!!row.errors}
              checked={get(formData, i, false) || false}
              onChange={(event) => setFormData({
                ...formData,
                [i]: event.target.checked
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