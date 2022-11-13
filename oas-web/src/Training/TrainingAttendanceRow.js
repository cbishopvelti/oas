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
  member,
  deleteAttendanceClick
}) => {
  const [open, setOpen] = useState(false);

  return <>
    <StyledTableRow className={`${member.errors && 'errors'} ${member.warnings && 'warnings'}`} key={member.id}>
      <TableCell>{member.id}</TableCell>
      <TableCell>{first(member.attendance)?.id}</TableCell>
      <TableCell>{member.name}</TableCell>
      <TableCell>{member.email}</TableCell>
      <TableCell sx={{...(member.tokens < 0 ? {color: "red"} : {})}}>{member.tokens}</TableCell>
      <TableCell>
        <IconButton title={`View ${member.name}'s tokens`} component={Link} to={`/member/${member.id}/tokens`}>
          <BookOnlineIcon />
        </IconButton>
        <IconButton title={`Delete ${member.name}'s attendance`} onClick={deleteAttendanceClick(first(member.attendance)?.id)}>
          <DeleteIcon sx={{color: 'red'}} />
        </IconButton>
        {(member.errors || member.warnings) && <IconButton
              aria-label="expand row"
              size="small"
              onClick={() => setOpen(!open)}
            >
          {open ? <KeyboardArrowUpIcon /> : <KeyboardArrowDownIcon />}
        </IconButton>}
      </TableCell>
    </StyledTableRow>
    {member.warnings && <StyledTableRow className={`${member.errors && 'errors'} ${member.warnings && 'warnings'}`}>
      <TableCell style={{ paddingBottom: 0, paddingTop: 0 }} colSpan={7}>
        <Collapse in={open} timeout="auto" unmountOnExit>
          <Stack sx={{ width: '100%' }}>
            {member.warnings?.map((item, i) => (
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