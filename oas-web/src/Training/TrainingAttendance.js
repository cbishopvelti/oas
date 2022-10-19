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
import { get } from 'lodash';
import { Link } from 'react-router-dom'
import BookOnlineIcon from '@mui/icons-material/BookOnline';


export const TrainingAttendance = ({trainingId}) => {

  console.log('201', trainingId)

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
      tokens
    }
  }`, {
    variables: {
      training_id: trainingId
    }
  });
  const members = get(data, 'members', []);
  const attendance = get(data, 'attendance', []);
  useEffect(() => {
    refetch()
  }, [])

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
    setAddAttendance({}) // DEBUG ONLY, uncomment
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
          onChange={(event, newValue, a, b, c, d) => {
            console.log('008', newValue)
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
              <TableCell>Id</TableCell>
              <TableCell>Name</TableCell>
              <TableCell>Email</TableCell>
              <TableCell>Tokens</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {
              attendance.map((member) => (
                <TableRow key={member.id}>
                  <TableCell>{member.id}</TableCell>
                  <TableCell>{member.name}</TableCell>
                  <TableCell>{member.email}</TableCell>
                  <TableCell sx={{...(member.tokens < 0 ? {color: "red"} : {})}}>{member.tokens}</TableCell>
                  <TableCell>
                    <IconButton component={Link} to={`/member/${member.id}/tokens`}>
                      <BookOnlineIcon />
                    </IconButton>
                  </TableCell>
                </TableRow>
              ))
            }
          </TableBody>
        </Table>
      </TableContainer>
    </div>
  </>

}
