import { useQuery, gql, useMutation } from "@apollo/client"
import { useEffect } from "react"
import {
  Table,
  TableContainer,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  IconButton,
  Box,
  FormControl,
  TextField,
  Button
} from '@mui/material';
import { get } from 'lodash';
import FitnessCenterIcon from '@mui/icons-material/FitnessCenter';
import DeleteIcon from '@mui/icons-material/Delete';
import { Link, useOutletContext } from "react-router-dom";
import moment from 'moment';
import { TrainingsFilter } from "./TrainingsFilter";
import { useState } from '../utils/useState';

export const Trainings = () => {
  const { setTitle } = useOutletContext();
  const [filterData, setFilterData ] = useState({
    from: moment().subtract(1, 'year').format("YYYY-MM-DD"),
    to: moment().add(1, 'month').format("YYYY-MM-DD")
  }, {id: "Trainings"});

  const {data, refetch} = useQuery(gql`
    query ($to: String!, $from: String!, $training_tag_ids: [Int]!, $training_where: [TrainingWhereArg]) {
      trainings(to: $to, from: $from, training_tag_ids: $training_tag_ids, training_where: $training_where) {
        id,
        training_where {
          id,
          name
        },
        when,
        attendance
      }
    }
  `, {
    variables: {
      ...filterData,
      training_tag_ids: get(filterData, "training_tags", []).map(({id}) => id)
    }
  })
  useEffect(() => {
    refetch()
  }, [filterData])
  useEffect(() => {
    let count = (get(data, ['trainings'], []) || []).length
    setTitle(`Trainings: ${count}`);
  }, [data])
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

  return <>
    <TrainingsFilter
      parentData={data}
      filterData={filterData}
      setFilterData={setFilterData} />
    <TableContainer>
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
          (trainings || []).map((training) => (
            <TableRow key={training.id}>
              <TableCell>{training.id}</TableCell>
              <TableCell>{training.when}</TableCell>
              <TableCell>{training.training_where.name}</TableCell>
              <TableCell>{training.attendance}</TableCell>
              <TableCell>
                <IconButton title={`Edit ${training.training_where.name} and add attendance`} component={Link} to={`/training/${training.id}`}>
                  <FitnessCenterIcon />
                </IconButton>
                {!training.attendance && <IconButton title={`Delete ${training.training_where.name}`} onClick={deleteTraningClick(training.id)}>
                  <DeleteIcon sx={{color: 'red'}} />
                </IconButton>}
              </TableCell>
            </TableRow>
          ))
        }
      </TableBody>
    </Table>
  </TableContainer>
  </>
}
