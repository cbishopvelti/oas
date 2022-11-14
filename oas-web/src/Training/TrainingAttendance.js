import { useEffect, useState } from 'react'
import { Box, FormControl, Autocomplete, TextField, Button,   Table,
  TableContainer,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  IconButton
} from "@mui/material"
import { useQuery, gql, useMutation } from '@apollo/client'
import { differenceBy, get } from 'lodash';
import { Link } from 'react-router-dom'
import { TrainingAttendanceRow } from './TrainingAttendanceRow';


export const TrainingAttendance = ({trainingId}) => {
  const [addAttendance, setAddAttendance] = useState({})

  let { data, refetch } = useQuery(gql`query ($training_id: Int!) {
    members {
      id,
      name
    },
    attendance (training_id: $training_id) {
      id,
      name,
      email,
      tokens,
      attendance {
        id
      },
      warnings
    }
  }`, {
    variables: {
      training_id: trainingId
    }
  });

  const attendance = get(data, 'attendance', []);
  const members = differenceBy(
    get(data, 'members', []),
    get(data, 'attendance', []),
    'id'
  );

  useEffect(() => {
    refetch()
  }, [trainingId])

  const [ mutate ] = useMutation(gql`
    mutation ($member_id: Int!, $training_id: Int!) {
      add_attendance(member_id: $member_id, training_id: $training_id) {
        id
      }
    }
  `);

  const addAttendanceClick = ({addAttendance, trainingId}) => async () => {
    await mutate({
      variables: {
        member_id: addAttendance.member_id,
        training_id: trainingId
      }
    })

    refetch()
    setAddAttendance({})
  }

  const [deleteAttendance ] = useMutation(gql`
    mutation ($attendance_id: Int!) {
      delete_attendance(attendance_id: $attendance_id) {
        success
      }
    }
  `)
  const deleteAttendanceClick = (attendanceId) => async (event) => {
    await deleteAttendance({
      variables: {
        attendance_id: attendanceId
      }
    })
    refetch();
  }

  return <>
    <Box sx={{m: 2}}>
      <h2 >Attendance</h2>
    </Box>
    <Box sx={{display: 'flex', flexWrap: 'wrap', alignItems: "center" }}>
      <FormControl sx={{m: 2, minWidth: 256}}>
        <Autocomplete
          id="member"
          value={addAttendance.member_name || ''}
          options={members.map(({name, id}) => ({label: name, member_id: id }))}
          renderInput={(params) => <TextField {...params} label="Who" />}
          freeSolo
          onChange={(event, newValue, a, b, c, d) => {
            setAddAttendance({
              member_id: newValue.member_id,
              member_name: newValue.label
            })
          }}
          />
      </FormControl>

      <FormControl sx={{m: 2}}>
        <Button onClick={addAttendanceClick({addAttendance, trainingId})}>Add</Button>
      </FormControl>
    </Box>
    <div>
      <TableContainer>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Member Id</TableCell>
              <TableCell>Attendance Id</TableCell>
              <TableCell>Name</TableCell>
              <TableCell>Email</TableCell>
              <TableCell>Tokens</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {
              attendance.map((member, i) => (
                <TrainingAttendanceRow key={i} member={member} deleteAttendanceClick={deleteAttendanceClick} />
              ))
            }
          </TableBody>
        </Table>
      </TableContainer>
    </div>
  </>

}
