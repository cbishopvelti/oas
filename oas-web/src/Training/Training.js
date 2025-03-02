import { gql, useQuery, useMutation } from "@apollo/client";
import { FormControl, TextField, Box, Button,
  Stack, Alert, Autocomplete, Tabs, Tab } from "@mui/material";
import TabContext from '@mui/lab/TabContext';
import TabList from '@mui/lab/TabList';
import TabPanel from '@mui/lab/TabPanel';
import { useEffect, useState as useReactState } from "react";
import { useState } from "../utils/useState";
import moment from "moment";
import { get, omit, has } from 'lodash'
import { useNavigate, useParams, useOutletContext } from "react-router-dom";
import { TrainingAttendance } from "./TrainingAttendance";
import { TrainingTags } from "./TrainingTags";
import { TrainingWhere } from "./TrainingWhere";
import { parseErrors } from "../utils/util";
import { TrainingForm } from "./TrainingForm";



export const Training = () => {
  const { setTitle } = useOutletContext();
  const navigate = useNavigate();
  let { id } = useParams()
  if (id) {
    id = parseInt(id)
  }
  const [attendance, setAttendance] = useReactState(0);

  const {data, refetch} = useQuery(gql`
    query($id: Int!) {
      training(id: $id) {
        id,
        when,
        notes,
        training_where {
          id,
          name
        }
        training_tags {
          id,
          name
        },
        attendance
      }
    }
  `, {
    variables: {
      id: id
    },
    skip: !id
  })

  const parent_attendance = get(data, 'training.attendance', 0)

  useEffect(() => {
    if (!id) {
      setTitle("New Training");
    } else {
      setTitle(`Editing Training: ${get(data, 'training.training_where.name', id)} on ${get(data, 'training.when', '')}: ${attendance || parent_attendance}`)
    }
  }, [get(data, 'training.training_where.name'), attendance, parent_attendance])

  const [{value}, setValue] = useState({value: (!id ? '1' : '2')}, {id: `trainings-tabs-${id}`});


  return <div>
    <Box sx={{display: 'flex', flexWrap: 'wrap' }}>
      <TabContext value={value}>
        <TabList sx={{width: '100%'}} onChange={(ev, newValue) => {
          setValue({value: newValue})
        }}>
          <Tab value={'1'} label="Training" />
          {id && <Tab value={'2'} label="Attendance" />}
        </TabList>
        <TabPanel value={'1'} sx={{width: '100%'}}>
          <TrainingForm id={id} data={data} refetch={refetch} />
        </TabPanel>
        {id &&
          <TabPanel value={'2'} sx={{width: '100%'}}>
            <TrainingAttendance setAttendance={setAttendance} trainingId={id} />
          </TabPanel>
        }
      </TabContext>
    </Box>
  </div>
}
