import { gql, useQuery, useMutation } from "@apollo/client";
import { FormControl, TextField, Box, Button,
  Stack, Alert, Autocomplete, Tabs, Tab,
  TableHead, TableContainer, TableCell, TableRow, Table,
  TableBody, IconButton} from "@mui/material";
import TabContext from '@mui/lab/TabContext';
import TabList from '@mui/lab/TabList';
import TabPanel from '@mui/lab/TabPanel';
import { useEffect, useState as useReactState } from "react";
// import { useState } from "../utils/useState";
import moment from "moment";
import { get, omit, has, pick } from 'lodash'
import { useNavigate, useParams, useOutletContext, Link } from "react-router-dom";
import { parseErrors } from "../utils/util";
import EditIcon from '@mui/icons-material/Edit';
import DeleteIcon from '@mui/icons-material/Delete';
import { dayToString } from "./VenueTime";


export const Venue = () => {
  const { setTitle } = useOutletContext();
  const navigate = useNavigate();
  let params = useParams()
  let id = params?.id
  const defaultData = {
    name: "",
    credit_amount: ""
  }
  const [formData, setFormData] = useReactState(defaultData);
  if (id) {
    id = parseInt(id)
  }
  const [attendance, setAttendance] = useReactState(0);

  const onChange = ({formData, setFormData, key}) => (event) => {
    setFormData({
      ...formData,
      [key]: !event.target.value ? undefined : event.target.value
    })
  }

  const {data, refetch} = useQuery(gql`
    query($id: Int!) {
      training_where(id: $id) {
        id,
        name,
        credit_amount,
        limit,
        training_where_time {
          id,
          day_of_week,
          start_time,
          recurring
        }
      }
    }
  `, {
    variables: {
      id: id
    },
    skip: !id
  })

  useEffect(() => {
    if (!id) {
      setTitle("New Venue");
    } else {
      setTitle(`Editing Venue: ${get(data, 'training_were.name', id)}`)
    }
    refetch()
    if (!id) {
      setFormData(defaultData)
    }
  }, [id])
  useEffect(() => {
    if (get(data, "training_where")) {
      setFormData({
        ...get(data, "training_where", {}),
        credit_amount: get(data, "training_where.credit_amount", "") || ""
      });
    }
  }, [data])

  const [mutate, {error}] = useMutation(gql`
    mutation($id: Int, $name: String!, $credit_amount: String!, $limit: Int) {
      training_where(id: $id, name: $name, credit_amount: $credit_amount, limit: $limit) {
        id
      }
    }
  `, {
    onError: () => { }
  })

  const save = (formData) => async () => {
    const variables = {
      ...formData
    }

    console.log("005", variables)
    const { data, errors } = await mutate({
      variables: {
        ...pick(variables, ["id", 'name', 'credit_amount']),
        limit: variables.limit ? parseInt(variables.limit) : null
      }
    });
    console.log("006", errors)

    setFormData({
      ...formData,
      saveCount: get(formData, "saveCount", 0) + 1
    })

    // return; // DEBUG ONLY, remove

    if (get(data, 'training_where.id')) {
      refetch()
      navigate(`/venue/${get(data, 'training_where.id')}`)
    }
  }

  const errors = parseErrors(error?.graphQLErrors);

  const [deleteTrainingWhereTimeMutation] = useMutation(gql`
    mutation($id: Int!) {
      delete_training_where_time(id: $id) {
        success
      }
    }
  `)
  const deleteTrainingWhereTime = (training_where_time_id) => async () => {
    await deleteTrainingWhereTimeMutation({
      variables: {
        id: training_where_time_id
      }
    })
    refetch();
  }

  return <div>
    <Box sx={{display: 'flex', flexWrap: 'wrap' }}>
      <FormControl fullWidth sx={{mt: 2, mb: 2, m: 2}}>
        <TextField
          required
          id="name"
          label="Name"
          value={get(formData, "name", '')}
          onChange={
            onChange({formData, setFormData, key: "name"})
          }
          InputLabelProps={{
            shrink: true,
          }}
          error={has(errors, "name")}
          helperText={get(errors, "name", []).join(" ")}
          />
      </FormControl>

      <FormControl fullWidth sx={{mt: 2, mb: 2, m: 2}}>
        <TextField
          required
          id="credit-amount"
          label="Amount"
          value={get(formData, "credit_amount", '')}
          onChange={
            onChange({formData, setFormData, key: "credit_amount"})
          }
          InputLabelProps={{
            shrink: true,
          }}
          inputMode="numeric"
          pattern="[0-9\.]*"
          error={has(errors, "credit_amount")}
          helperText={get(errors, "credit_amount", []).join(" ")}
          />
      </FormControl>

      <FormControl fullWidth sx={{ m: 2 }}>
        <TextField
          id="limit"
          label="Limit"
          value={get(formData, "limit", '') || ''}
          onChange={
            onChange({formData, setFormData, key: "limit"})
          }
          InputLabelProps={{
            shrink: true
          }}
          inputMode="numeric"
          pattern="[0-9]*"
          error={has(errors, "limit")}
          helperText={get(errors, "limit", []).join(" ")}
          />
      </FormControl>

      <FormControl fullWidth sx={{m: 2}}>
        <Button onClick={save(formData)}>Save</Button>
      </FormControl>
    </Box>
    {id && <Box sx={{ mt: 2, mb: 2, m: 2 }}>
      <div style={{ display: "flex", justifyContent: "space-between" }}>
        <h3 style={{ display: "inline" }}>Times</h3>

        <Button
          to={`/venue-time/${id}`}
          component={Link}>Add time</Button>
      </div>

      <TableContainer>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Id</TableCell>
              <TableCell>Day of week</TableCell>
              <TableCell>Start time</TableCell>
              <TableCell>Recurring</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {get(data, 'training_where.training_where_time', []).map((training_where_time, i) => {
              return <TableRow key={i}>
                <TableCell>{training_where_time.id}</TableCell>
                <TableCell>{dayToString(training_where_time.day_of_week)}</TableCell>
                <TableCell>{training_where_time.start_time}</TableCell>
                <TableCell>{(training_where_time.recurring || false).toString()}</TableCell>
                <TableCell>
                  <IconButton title={`Edit ${training_where_time.id}`} component={Link} to={`/venue-time/${id}/${training_where_time.id}`}>
                    <EditIcon />
                  </IconButton>
                  <IconButton title={`Delete ${training_where_time.id}`} onClick={deleteTrainingWhereTime(training_where_time.id)}>
                    <DeleteIcon sx={{color: "red"}} />
                  </IconButton>
                </TableCell>
              </TableRow>
            })}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>}
  </div>
}
