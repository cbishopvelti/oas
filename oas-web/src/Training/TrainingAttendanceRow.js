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


export const TrainingAttendanceRow = ({
  attendance,
  deleteAttendanceClick
}) => {
  const [open, setOpen] = useState(false);

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