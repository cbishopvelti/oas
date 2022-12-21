import {
  Box, TableContainer, Table, TableHead,
  TableBody, TableCell, TableRow, Button
} from '@mui/material';
import { useQuery, gql, useMutation } from '@apollo/client';
import { has, get } from 'lodash';

const canUndo = (booking) => {
  
}

export const Bookings = () => {

  // List of upcoming trainings
  const {data, refetch} = useQuery(gql`
    query {
      user_bookings {
        id,
        where, 
        when,
        attendance_id,
        inserted_by_member_id
      }
    }
  `);

  // console.log("001", data);

  const [attendMutation] = useMutation(gql`
    mutation($training_id: Int!) {
      user_add_attendance(training_id: $training_id) {
        success
      }
    }
  `)
  const onAttend = (training_id) => async (event) => {
    await attendMutation({
      variables: {
        training_id: training_id
      }
    })
    refetch();
  }

  return <Box>
    <h2>My Bookings</h2>
    {!has(data, "user_bookings") && <p>No upcoming jams/trainings</p>}
    {has(data, "user_bookings") && <TableContainer><Table>
      <TableHead>
        <TableRow>
          <TableCell>Where</TableCell>
          <TableCell>When</TableCell>
          <TableCell>Actions</TableCell>
        </TableRow>
      </TableHead>
      <TableBody>
        {get(data, "user_bookings", []).map((training, i) => {
          return <TableRow key={i}>
            <TableCell>{training.where}</TableCell>
            <TableCell>{training.when}</TableCell>
            <TableCell>
              {!training.attendance_id && <Button onClick={onAttend(training.id)} color="success" sx={{width: '100%'}}>Attend</Button>}
            </TableCell>
          </TableRow>
        })}
      </TableBody>
    </Table></TableContainer>}
  </Box>
}
