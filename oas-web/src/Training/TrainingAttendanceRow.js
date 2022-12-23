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

const canUndo = (attendance) => {
  if (attendance.inserted_by_member_id !== attendance.member.id) {
    return false;
  }

  if (
    moment().isBefore(attendance.training.when)
  ) {
    return moment(attendance.training.when)
  }
    
  if (
    moment(attendance.inserted_at).isSame(attendance.training.when, 'day') && 
    moment().isBefore(moment(attendance.inserted_at).add(60, 'seconds'))
  ) {
    return moment(attendance.inserted_at).add(60, 'seconds')
  } 
  return false;
}

export const TrainingAttendanceRow = ({
  attendance,
  deleteAttendanceClick,
  refetch
}) => {
  const [open, setOpen] = useState(false);
  const [state, setState] = useState({update: 0})

  const expires = canUndo(attendance);

  return <>
    <StyledTableRow className={`${attendance.errors && 'errors'} ${attendance.warnings && 'warnings'}`} key={attendance.id}>
      <TableCell>{attendance.member.id}</TableCell>
      <TableCell>{attendance.id}</TableCell>
      <TableCell>{attendance.member.name}</TableCell>
      <TableCell>{attendance.member.email}</TableCell>
      <TableCell>{attendance.member.member_status}</TableCell>
      <TableCell sx={{...(attendance.member.token_count < 0 ? {color: "red"} : {})}}>{attendance.member.token_count}</TableCell>
      <TableCell>
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
      <TableCell style={{ paddingBottom: 0, paddingTop: 0 }} colSpan={7}>
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