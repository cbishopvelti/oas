import { gql, useQuery, useMutation } from "@apollo/client";
import { TableBody, TableCell, TableContainer, TableHead, TableRow, Table, IconButton } from "@mui/material";
import { useEffect } from "react"
import { useParams, useOutletContext, Link } from "react-router-dom";
import { get } from 'lodash';
import FitnessCenterIcon from '@mui/icons-material/FitnessCenter';
import PaidIcon from '@mui/icons-material/Paid';
import DeleteIcon from '@mui/icons-material/Delete';

export const MemberTrainingAttendance = () => {
  const { setTitle } = useOutletContext();
  let { member_id } = useParams();
  if (member_id) {
    member_id = parseInt(member_id);
  }

  const {data, refetch} = useQuery(gql`
    query ($member_id: Int!){
      member(member_id: $member_id) {
        name
      },
      member_attendance(member_id: $member_id) {
        id,
        member {
          id,
          member_status,
          name
        },
        token {
          id,
          transaction {
            id
          }
        },
        training {
          id,
          training_where {
            name
          },
          when
        }
      }
    }
  `, {
    variables: {
      member_id
    }
  });

  const member = get(data, 'member', {});
  const member_attendance = get(data, 'member_attendance', []);
  useEffect(() => {
    setTitle(`Member: ${get(member, 'name', member_id)}'s Attendance`);
  }, [get(member, 'name')])


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

  console.log("001 data", data);
  // TODO, member_status

  // actions, go to training, go to token's transaction, delete attendance 
    
  return <>
    <TableContainer><Table>
      <TableHead>
        <TableRow>
          <TableCell>
            Id
          </TableCell>
          <TableCell>
            When
          </TableCell>
          <TableCell>
            Where
          </TableCell>
          <TableCell>
            Member Status
          </TableCell>
          <TableCell>
            Actions
          </TableCell>
        </TableRow>
      </TableHead>
      <TableBody>
        {member_attendance.map((attendance) => {

          const sx = {
            ...(!attendance.token?.id || true ? {
              color: "gray",
              textDecoration: "line-through"
            }: {})
          }

          return <TableRow key={attendance.id}>
            <TableCell sx={sx}>{attendance.id}</TableCell>
            <TableCell sx={sx}>{attendance.training.when}</TableCell>
            <TableCell sx={sx}>{attendance.training.training_where.name}</TableCell>
            <TableCell sx={sx}>{attendance.member.member_status}</TableCell>
            <TableCell sx={sx}>
              <IconButton title={`Go to training ${attendance.training.training_where.name}'s training`} component={Link} to={`/training/${attendance.training.id}`}>
                <FitnessCenterIcon />
              </IconButton>
              {attendance.token?.transaction?.id && <IconButton title={`Go to this token's transaction`} component={Link} to={`/transaction/${attendance.token?.transaction?.id}`}>
                <PaidIcon />
              </IconButton>}
              <IconButton title={`Delete this attendance`} onClick={deleteAttendanceClick(attendance.id)}>
                <DeleteIcon sx={{color: 'red'}} />
              </IconButton>
            </TableCell>
          </TableRow>
        })}
      </TableBody>
    </Table></TableContainer>
  </>
}