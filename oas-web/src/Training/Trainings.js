import { useQuery, gql, useMutation } from "@apollo/client"
import { useEffect, useState } from "react"
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
import { Link } from "react-router-dom";
import moment from 'moment';
import { TrainingTags } from "./TrainingTags";
import { TrainingWhereFilter } from "./TrainingWhereFilter";

const onChange = ({formData, setFormData, key}) => (event) => {   
  setFormData({
    ...formData,
    [key]: !event.target.value ? undefined : event.target.value
  })
}

export const Trainings = () => {
  const [filterData, setFilterData ] = useState({
    from: moment().subtract(1, 'year').format("YYYY-MM-DD"),
    to: moment().format("YYYY-MM-DD")
  });

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

  console.log("101", setFilterData)
  return <>
    <Box sx={{display: 'flex', flexWrap: 'wrap' }}>
      <FormControl sx={{m: 2, minWidth: 256}}>
        <TextField
          required
          id="from"
          label="From"
          type="date"
          value={get(filterData, "from")}
          onChange={onChange({formData: filterData, setFormData: setFilterData, key: "from"})}
          InputLabelProps={{
            shrink: true,
          }}
        />
      </FormControl>
      <FormControl sx={{m: 2, minWidth: 256}}>
        <TextField
          required
          id="from"
          label="From"
          type="date"
          value={get(filterData, "to")}
          onChange={onChange({formData: filterData, setFormData: setFilterData, key: "to"})}
          InputLabelProps={{
            shrink: true,
          }}
        />
      </FormControl>
      {/* <FormControl sx={{m: 2, minWidth: 256}}>
        <TrainingTags 
          formData={filterData}
          setFormData={setFilterData}
          filterMode={true}
        />
      </FormControl> */}
      <FormControl sx={{m: 2, minWidth: 256}}>
        <TrainingWhereFilter
          setFormData={setFilterData}
          formData={filterData}
        />
      </FormControl>
    </Box>
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
          trainings.map((training) => (
            <TableRow key={training.id}>
              <TableCell>{training.id}</TableCell>
              <TableCell>{training.when}</TableCell>
              <TableCell>{training.training_where.name}</TableCell>
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
  </>
}