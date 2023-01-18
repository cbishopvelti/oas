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
import { differenceBy, get, chain } from 'lodash';
import { Link } from 'react-router-dom'
import { TrainingAttendanceRow } from './TrainingAttendanceRow';


export const TrainingAttendance = ({trainingId, setAttendance}) => {

  const [addAttendance, setAddAttendance] = useState({})

  // name,
  //     email,
  //     tokens,
  //     member_status,
  //     attendance {
  //       id
  //     },
  //     warnings
  let { data, refetch } = useQuery(gql`query attendance($training_id: Int!) {
    members {
      id,
      name
    },
    attendance (training_id: $training_id) {
      id,
      warnings, 
      member {
        id,
        name,
        email,
        token_count,
        member_status
      },
      inserted_at,
      inserted_by_member_id,
      training {
        when
      }
    },
    config_config {
      enable_booking
    }
  }`, {
    variables: {
      training_id: trainingId
    }
  });

  const attendance = get(data, 'attendance', []);

  useEffect(() => {
    setAttendance(attendance.length)
  }, [attendance])

  const attendanceMembers = chain(get(data, 'attendance', []))
    .map(({member}) => member)
    .uniqBy('id')
    .value()

  const members = differenceBy(
    get(data, 'members', []),
    attendanceMembers,
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
    <Box sx={{display: 'flex', flexWrap: 'wrap', alignItems: "center" }}>
      <FormControl sx={{mb: 2, minWidth: 256}}>
        <Autocomplete
          id="member"
          value={addAttendance.member_name || ''}
          options={members.map(({name, id}) => ({label: name, member_id: id }))}
          renderInput={(params) => <TextField {...params} label="Who" />}
          freeSolo
          onChange={(event, newValue, a, b, c, d) => {
            if (!newValue) {
              return
            }
            setAddAttendance({
              member_id: newValue.member_id,
              member_name: newValue.label
            })
          }}
          />
      </FormControl>

      <FormControl sx={{ml: 2, mb: 2}}>
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
              <TableCell>Status</TableCell>
              <TableCell>Tokens</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {
              (attendance || []).map((attendance, i) => (
                <TrainingAttendanceRow
                  key={i}
                  attendance={attendance}
                  deleteAttendanceClick={deleteAttendanceClick}
                  refetch={refetch}
                  config={get(data, "config_config", {})}
                  />
              ))
            }
          </TableBody>
        </Table>
      </TableContainer>
    </div>
  </>

}
