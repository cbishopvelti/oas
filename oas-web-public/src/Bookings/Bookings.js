import {
  Box, TableContainer, Table, TableHead,
  TableBody, TableCell, TableRow, Button
} from '@mui/material';
import { useQuery, gql, useMutation } from '@apollo/client';
import { has, get } from 'lodash';
import moment from 'moment';
import { useOutletContext } from 'react-router-dom';
import { UndoButton } from './UndoButton';

const canUndo = ({
  user
}) => (booking) => {
  if (booking.inserted_by_member_id !== user.id) {
    return false;
  }
  if (!booking.attendance_id) {
    return false;
  }

  if (
    moment().isBefore(booking.undo_until)
  ) {
    // return moment(booking.when).diff(moment(), 'seconds')
    return moment(booking.undo_until)
  }
  
  return false;
}

export const Bookings = () => {
  const [{user}] = useOutletContext();

  // List of upcoming trainings
  const {data, refetch} = useQuery(gql`
    query {
      user_bookings {
        id,
        where, 
        when,
        attendance_id,
        inserted_by_member_id,
        inserted_at,
        undo_until
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
              {user && canUndo({user})(training) && <UndoButton
                refetch={refetch}
                expires={canUndo({user})(training)}
              >Undo</UndoButton>}
              {training.attendance_id && user && !canUndo({user})(training) && <Button disabled={true} sx={{width: '100%'}} color="success">Attending</Button>}
            </TableCell>
          </TableRow>
        })}
      </TableBody>
    </Table></TableContainer>}
  </Box>
}
