import { useState } from 'react'
import {
  Box, FormControl, Autocomplete, TextField, Button,   Table,
  TableContainer,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  IconButton,
  Collapse,
  Stack,
  Alert
} from '@mui/material'
import { StyledTableRow } from '../utils/util'
import { Link } from 'react-router-dom';
import BookOnlineIcon from '@mui/icons-material/BookOnline';
import DeleteIcon from '@mui/icons-material/Delete';
import { first } from 'lodash'
import KeyboardArrowDownIcon from '@mui/icons-material/KeyboardArrowDown';
import KeyboardArrowUpIcon from '@mui/icons-material/KeyboardArrowUp';
import { TrainingAttendanceRowUndo } from './TrainingAttendanceRowUndo';
import moment from 'moment';
import { isString } from 'lodash';
import SaveIcon from '@mui/icons-material/Save';
import { useMutation, gql } from '@apollo/client';

const canUndo = (attendance, {enable_booking}) => {
  if (!enable_booking) {
    return false;
  }
  if (attendance.inserted_by_member_id !== attendance.member.id) {
    return false;
  }

  if (
    !attendance.training.commitment &&
    moment().isBefore(attendance.booking_cutoff)
  ) {
    return moment(attendance.booking_cutoff)
  }

  if (
    (moment(attendance.inserted_at).isSame(attendance.training.when, 'day') || attendance.training.commitment) &&
    moment().isBefore(moment(attendance.inserted_at).add(60, 'seconds'))
  ) {
    return moment(attendance.inserted_at).add(60, 'seconds')
  }
  return false;
}

export const TrainingAttendanceRow = ({
  attendance,
  deleteAttendanceClick,
  refetch,
  config
}) => {
  const [open, setOpen] = useState(false);
  const [state, setState] = useState({update: 0})
  const [newAmount, setNewAmount] = useState(null);

  const expires = canUndo(attendance, config);

  const [mutation] = useMutation(gql`
    mutation($amount: String!, $id: Int!) {
      save_credit_amount(amount: $amount, id: $id) {
        success
      }
    }
  `)
  const saveNewAmount = async () => {
    await mutation({
      variables: {
        amount: newAmount,
        id: attendance.credit.id
      }
    })
    setNewAmount(null);
    refetch()
  }

  return <>
    <StyledTableRow className={`${attendance.errors && 'errors'} ${attendance.warnings && 'warnings'}`} key={attendance.id}>
      <TableCell>{attendance.member.id}</TableCell>
      <TableCell>{attendance.id}</TableCell>
      <TableCell>{attendance.member.name}</TableCell>
      {/* <TableCell>{attendance.member.email}</TableCell> */}
      <TableCell>{attendance.member.member_status}</TableCell>
      <TableCell sx={{...(attendance.member.token_count < 0 ? {color: "red"} : {})}}>{attendance.member.token_count}</TableCell>
      <TableCell>
        <TextField
          variant="standard"
          type="text"
          inputMode="numeric"
          pattern="[\-0-9\.]*"
          value={isString(newAmount) ? newAmount : attendance?.credit?.amount}
          onChange={(event) => {
            setNewAmount(event.target.value)
          }}
          onBlur={() => {
            if (isNaN(parseFloat(newAmount))) {
              setNewAmount(null)
            }
          }}
        />
      </TableCell>
      <TableCell sx={{ ...(attendance.member.credit_amount < 0 ? { color: "red" } : {}) }}>{ attendance.member.credit_amount }</TableCell>
      <TableCell>
        {isString(newAmount) && !isNaN(parseFloat(newAmount)) && <IconButton
          title={`Save`}
          onClick={() => {
            saveNewAmount()
          } }
          >
          <SaveIcon />
        </IconButton>}
        <IconButton title={`View ${attendance.member.name}'s tokens`} component={Link} to={`/member/${attendance.member.id}/tokens`}>
          <BookOnlineIcon />
        </IconButton>
        <IconButton title={`Delete ${attendance.member.name}'s attendance`} onClick={deleteAttendanceClick(attendance.id)}>
          <DeleteIcon sx={{color: 'red'}} />
        </IconButton>
        {(attendance.errors || attendance.warnings) && <IconButton
              aria-label="expand row"
              size="small"
              onClick={() => setOpen(!open)}
            >
          {open ? <KeyboardArrowUpIcon /> : <KeyboardArrowDownIcon />}
        </IconButton>}
        {expires && <TrainingAttendanceRowUndo state={state} setState={setState} expires={expires} attendance={attendance} refetch={refetch} />}
      </TableCell>
    </StyledTableRow>
    {attendance.warnings && <StyledTableRow className={`${attendance.errors && 'errors'} ${attendance.warnings && 'warnings'}`}>
      <TableCell style={{ paddingBottom: 0, paddingTop: 0 }} colSpan={8}>
        <Collapse in={open} timeout="auto" unmountOnExit>
          <Stack sx={{ width: '100%' }}>
            {attendance.warnings?.map((item, i) => (
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
