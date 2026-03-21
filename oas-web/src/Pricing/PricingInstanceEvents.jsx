import { Box, FormControl, Button,
  IconButton, Dialog, DialogTitle,
  Autocomplete, TextField,
  Table,
  TableContainer,
  TableBody,
  TableRow,
  TableHead,
  TableCell
} from "@mui/material"
import { useState } from "react";
import { useQuery, gql, useMutation } from "@apollo/client";
import { get, differenceBy, has } from "lodash";
import moment from "moment";
import { parseErrors } from "../utils/util";
import { useEffect } from "react";
import DeleteIcon from '@mui/icons-material/Delete';


const AddTraining = ({pricing_instance_id, trainings: existing_trainings, open, setOpen, changeNo, setChangeNo}) => {
  const [training, setTraining] = useState(undefined);

  let { data, refetch: refetchTrainings } = useQuery(gql`query($from: String!, $to: String! ) {
    trainings (from: $from, to: $to ) {
      id,
      when
    }
  }`, {
    variables: {
      from: moment().subtract(1, 'year').format("YYYY-MM-DD"),
      to: moment().add(1, 'year').format("YYYY-MM-DD")
    }
  });
  useEffect(() => {
    refetchTrainings()
  }, [changeNo])
  let trainings = get(data, 'trainings', []);
  trainings = differenceBy(trainings, existing_trainings, ({id}) => { return id })

  let [mutate, {error: mutationError}] = useMutation(gql`
    mutation($training_id: Int!, $pricing_instance_id: Int!) {
      pricing_instance_add_training(training_id: $training_id, pricing_instance_id: $pricing_instance_id) {
        id
      }
    }
  `)
  const addTrainingClick = async () => {
    try {
      await mutate({
        variables: {
          training_id: training.id,
          pricing_instance_id
        }
      })
      setChangeNo(changeNo + 1)
      setTraining(undefined)
      setOpen(false)
    } catch (error) {
      console.error(error)
    }
  }
  const errors = parseErrors([
    ...get(mutationError, "graphQLErrors", [])
  ])

  return <>
      <Dialog open={open} onClose={() => {setOpen(false)}}>
        <DialogTitle>Select training to add</DialogTitle>
        <FormControl sx={{m: 2, minWidth: 256}}>
          <Autocomplete
            id="training"
            required
            value={training ? `${training.label}` : null}
            isOptionEqualToValue={(a, b) => {
              return a.label === b
            }}
            options={trainings.map(({when, id}) => ({label: `${id}, ${when}`, training_id: id }))}
            renderInput={(params) => <TextField {...params} required label="When"
              error={has(errors, "pricing_instance_id")}
              helperText={get(errors, "pricing_instance_id", []).join(" ")}/>}
            onChange={(event, newValue, a, b, c, d) => {
              setTraining({
                id: newValue.training_id,
                label: newValue.label
              })
            }}
            />
        </FormControl>
        <FormControl sx={{m: 2}}>
          <Button onClick={addTrainingClick}>Add to pricing instance</Button>
        </FormControl>
      </Dialog>
    </>
}

export const PricingInstanceEvents = ({
  pricingInstance,
  refetch
}) => {
  const [open, setOpen] = useState(false)
  const [changeNo, setChangeNo] = useState(0);


  useEffect(() => {
    refetch()
  }, [changeNo])

  const [deleteMutation] = useMutation(gql`mutation ($training_id: Int!, $pricing_instance_id: Int!) {
    pricing_instance_delete_training(training_id: $training_id, pricing_instance_id: $pricing_instance_id) {
      success
    }
  }`)

  const deleteClick = (id) => async () => {
    console.log("TODO deleteClick")
    await deleteMutation({
      variables: {
        training_id: id,
        pricing_instance_id: pricingInstance.id
      }
    })
    setChangeNo(changeNo + 1)
  }

  return <Box>
    <div style={{ display: "flex", justifyContent: "space-between" }}>
      <h3 style={{ display: "inline" }}>Trainings</h3>

      <Button onClick={() => {setOpen(true)}}>Add Training</Button>
    </div>
    <AddTraining
      changeNo={changeNo}
      setChangeNo={setChangeNo}
      open={open}
      setOpen={setOpen}
      pricing_instance_id={pricingInstance.id}
      trainings={pricingInstance.trainings}
    />
    <TableContainer>
      <Table>
        <TableHead>
          <TableRow>
            <TableCell>id</TableCell>
            <TableCell>When</TableCell>
            <TableCell>Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {(pricingInstance.trainings || []).map((training, i) => {
            return <TableRow key={i}>
              <TableCell>{training.id}</TableCell>
              <TableCell>{training.when}</TableCell>
              <TableCell>
                <IconButton onClick={deleteClick(training.id)}>
                  <DeleteIcon sx={{color: 'red'}}/>
                </IconButton>
              </TableCell>
            </TableRow>
          })}
        </TableBody>
      </Table>
    </TableContainer>
  </Box>
}
