import { useQuery, gql, useMutation } from "@apollo/client"
import { useEffect } from "react"
import {
  Table,
  TableContainer,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  IconButton
} from '@mui/material';
import { get } from 'lodash';
import FitnessCenterIcon from '@mui/icons-material/FitnessCenter';
import DeleteIcon from '@mui/icons-material/Delete';
import { Link } from "react-router-dom"



export const Trainings = () => {

  const {data, refetch} = useQuery(gql`
    query {
      trainings {
        id,
        where, 
        when,
        attendance
      }
    }
  `)
  useEffect(() => {
    refetch()
  }, [])
  const trainings = get(data, 'trainings', [])

  const [deleteMutation] = useMutation(gql`
    mutation($id: Int!) {
      delete_training(id: $id) {
        success
      }
    }
  `)
  const deleteTraningClick = (id) => async () => {
    await deleteMutation({
      variables: {
        id: id
      }
    })
    refetch();
  }

  return <TableContainer>
  <Table>
    <TableHead>
      <TableRow>
        <TableCell>Id</TableCell>
        <TableCell>When</TableCell>
        <TableCell>Where</TableCell>
        <TableCell>Attendance</TableCell>
        <TableCell>Actions</TableCell>
      </TableRow>
    </TableHead>
    <TableBody>
      {
        trainings.map((training) => (
          <TableRow key={training.id}>
            <TableCell>{training.id}</TableCell>
            <TableCell>{training.when}</TableCell>
            <TableCell>{training.where}</TableCell>
            <TableCell>{training.attendance}</TableCell>
            <TableCell>
              <IconButton component={Link} to={`/training/${training.id}`}>
                <FitnessCenterIcon />
              </IconButton>
              {!training.attendance && <IconButton onClick={deleteTraningClick(training.id)}>
                <DeleteIcon />
              </IconButton>}
            </TableCell>
          </TableRow>
        ))
      }
    </TableBody>
  </Table>
</TableContainer>
}