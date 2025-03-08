import { gql, useQuery, useMutation } from "@apollo/client";
import { FormControl, TextField, Box, Button, Stack, Alert, Tabs, Tab, Table,
  TableContainer, TableHead, TableRow, TableCell, TableBody } from "@mui/material";
import TabContext from '@mui/lab/TabContext';
import TabList from '@mui/lab/TabList';
import TabPanel from '@mui/lab/TabPanel';
import { useEffect, useState as useReactState } from "react";
import { useState } from "../utils/useState";
import moment from "moment";
import { get, has } from 'lodash';
import { useNavigate, useParams, useOutletContext } from "react-router-dom";
import { parseErrors } from "../utils/util";
import { ThingForm } from './ThingForm';
import { ThingCredits } from './ThingCredits';

export const Thing = () => {
  const { setTitle } = useOutletContext();
  const navigate = useNavigate();
  let { id } = useParams();
  if (id) {
    id = parseInt(id);
  }

  const { data, refetch } = useQuery(gql`
    query($id: Int!) {
      thing(id: $id) {
        id,
        what,
        value,
        when
      }
    }
  `, {
    variables: {
      id: id
    },
    skip: !id
  });

  useEffect(() => {
    if (!id) {
      setTitle("New Thing");
    } else {
      setTitle(`Editing Thing: ${get(data, 'thing.what', id)}`);
    }
  }, [id, data, setTitle]);

  const [{value}, setValue] = useState({value: '1'}, {id: `thing-tabs-${id}`});

  return (
    <div>
      <Box sx={{display: 'flex', flexWrap: 'wrap' }}>
        <TabContext value={value}>
          <TabList sx={{width: '100%'}} onChange={(ev, newValue) => {
            setValue({value: newValue})
          }}>
            <Tab value={'1'} label="Thing Details" />
            {id && <Tab value={'2'} label="Purchasers" />}
          </TabList>
          <TabPanel value={'1'} sx={{width: '100%'}}>
            <ThingForm id={id} data={data} refetch={refetch} />
          </TabPanel>
          {id &&
            <TabPanel value={'2'} sx={{width: '100%'}}>
              <ThingCredits thingId={id} />
            </TabPanel>
          }
        </TabContext>
      </Box>
    </div>
  );
};
