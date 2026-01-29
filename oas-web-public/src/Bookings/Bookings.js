import { useState, useEffect, useRef } from 'react';
import {
  Box, TableContainer, Table, TableHead,
  TableBody, TableCell, TableRow, Button
} from '@mui/material';
import { useQuery, gql, useMutation, useSubscription } from '@apollo/client';
import { has, get } from 'lodash';
import moment from 'moment';
import { useOutletContext, redirect, useNavigate } from 'react-router-dom';
import { UndoButton } from './UndoButton';
import { CreditWarning } from './CreditWarning';

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
    !booking.commitment && booking.booking_cutoff
  ) {
    if (moment().isBefore(booking.booking_cutoff)) {
      return moment(booking.booking_cutoff)
    }
  }

  if (
    (moment(booking.inserted_at).isSame(booking.when, 'day') || booking.commitment) &&
    moment().isBefore(moment(booking.inserted_at).add(60, 'seconds'))
  ) {
    return moment(booking.inserted_at).add(60, 'seconds')
  }


  return false;
}

export const Bookings = () => {
  const [state, setState] = useState({
    update: 0
  })
  const [{ user, userLoading }] = useOutletContext();

  const navigate = useNavigate();


  useEffect(() => {
    if (!user && userLoading === false) {
      window.location.href=`${process.env.REACT_APP_SERVER_URL}/members/log_in`
    }
  } , [user, userLoading])

  // List of upcoming trainings
  const {data, refetch} = useQuery(gql`
    query {
      user_bookings {
        id,
        where,
        when,
        start_time,
        booking_cutoff,
        attendance_id,
        inserted_by_member_id,
        inserted_at,
        commitment
      }
    }
  `, {
    nextFetchPolicy: "cache-and-network",
    refetchWritePolicy: "merge"
  });

  const {data: subData} = useSubscription(gql`subscription {
    user_attendance_attendance {
      success
    }
  }`, {
    onData({ data }) {
      console.log("005 user_attendance_attendance SHOULD HAPPEN")
      refetch()
    }
  })

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

  const [undoMutation] = useMutation(gql`
    mutation($attendance_id: Int!) {
      user_undo_attendance(attendance_id: $attendance_id) {
        success
      }
    }
  `)
  const undo = (attendance_id) => async(event) => {
    await undoMutation({
      variables: {
        attendance_id
      }
    })
    refetch();
  }



  return <Box className="" sx={{}}>
    <h2>My Bookings</h2>
    <CreditWarning watch={ get(data, "user_bookings") } />
    {(!has(data, "user_bookings") || get(data, "user_bookings", []).length == 0) && <p>No upcoming events</p>}
    {(has(data, "user_bookings") && get(data, "user_bookings", []).length != 0) && <TableContainer><Table>
      <TableHead>
        <TableRow>
          <TableCell>Where</TableCell>
          <TableCell>When</TableCell>
          <TableCell>Start time</TableCell>
          <TableCell>Actions</TableCell>
        </TableRow>
      </TableHead>
      <TableBody>
        {get(data, "user_bookings", []).map((training, i) => {
          return <TableRow key={i} sx={{tableLayout: "fixed", width: "100%"}}>
            <TableCell sx={{width: "20%"}}>{training.where}</TableCell>
            <TableCell sx={{width: "20%"}}>{training.when}</TableCell>
            <TableCell sx={{ width: "20%" }}>{training.start_time && moment(training.start_time, "HH:mm:ss").format("HH:mm")}</TableCell>
            <TableCell sx={{width: "20%"}}>
              {!training.attendance_id && <Button onClick={onAttend(training.id)} color="success" sx={{width: "100%"}}>Attend</Button>}
              {user && canUndo({user})(training) && <UndoButton
                refetch={refetch}
                expires={canUndo({user})(training)}
                state={state}
                setState={setState}
                onClick={undo(training.attendance_id)}
              >Undo</UndoButton>}
              {training.attendance_id && user && !canUndo({user})(training) && <Button disabled={true} sx={{width: "100%"}} color="success">Attending</Button>}
            </TableCell>
          </TableRow>
        })}
      </TableBody>
    </Table></TableContainer>}
  </Box>
}
