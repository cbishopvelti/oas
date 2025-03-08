import { gql, useQuery, useMutation } from "@apollo/client";
import { FormControl, TextField, Box, Button, Stack, Alert, Tabs, Tab, Table,
  TableContainer, TableHead, TableRow, TableCell, TableBody } from "@mui/material";
import TabContext from '@mui/lab/TabContext';
import TabList from '@mui/lab/TabList';
import TabPanel from '@mui/lab/TabPanel';
import { useEffect, useState } from "react";
import moment from "moment";
import { get, has } from 'lodash';
import { useNavigate, useParams, useOutletContext } from "react-router-dom";
import { parseErrors } from "../utils/util";

export const ThingForm = ({ id, data, refetch }) => {
  const navigate = useNavigate();

  const defaultData = {
    what: "",
    value: "",
    when: moment().format("YYYY-MM-DD")
  };

  const [formData, setFormData] = useState(defaultData);

  useEffect(() => {
    if (!id) {
      setFormData(defaultData);
    }
  }, [id]);

  useEffect(() => {
    if (!data) {
      return;
    }
    setFormData({
      ...get(data, "thing")
    });
  }, [data]);

  const onChange = (key) => (event) => {
    setFormData({
      ...formData,
      [key]: !event.target.value ? undefined : event.target.value
    });
  };

  const [upsertMutation, { error: upsertError }] = useMutation(gql`
    mutation ($id: Int, $what: String!, $value: String, $when: String!) {
      thing(id: $id, what: $what, value: $value, when: $when) {
        id
      }
    }
  `);

  const save = async () => {
    try {
      if (!id) {
        const { data } = await upsertMutation({
          variables: formData
        });
        navigate(`/thing/${get(data, "thing.id")}`);
      } else {
        await upsertMutation({
          variables: formData
        });
        refetch();
      }
    } catch (error) {
      console.error("Error saving thing:", error);
    }
  };

  const errors = parseErrors([
    ...get(upsertError, "graphQLErrors", []),
  ]);

  return (
    <Box sx={{ width: '100%' }}>
      <Stack sx={{ width: '100%' }}>
        {errors.global?.map((message, i) => (
          <Alert key={i} sx={{ m: 2 }} severity="error">{message}</Alert>
        ))}
      </Stack>

      <FormControl fullWidth sx={{ mt: 2, mb: 2 }}>
        <TextField
          required
          id="what"
          label="What"
          value={get(formData, "what", '')}
          type="text"
          onChange={onChange("what")}
          error={has(errors, "what")}
          helperText={get(errors, "what", []).join(" ")}
        />
      </FormControl>

      <FormControl fullWidth sx={{ mt: 2, mb: 2 }}>
        <TextField
          id="value"
          label="Value"
          value={get(formData, "value", '')}
          type="text"
          onChange={onChange("value")}
          error={has(errors, "value")}
          helperText={get(errors, "value", []).join(" ")}
        />
      </FormControl>

      <FormControl fullWidth sx={{ mt: 2, mb: 2 }}>
        <TextField
          required
          id="when"
          label="When"
          value={get(formData, "when", '')}
          type="date"
          onChange={onChange("when")}
          InputLabelProps={{
            shrink: true,
          }}
          error={has(errors, "when")}
          helperText={get(errors, "when", []).join(" ")}
        />
      </FormControl>

      <FormControl fullWidth sx={{ mt: 2, mb: 2 }}>
        <Button variant="contained" onClick={save}>
          {id ? "Update" : "Create"} Thing
        </Button>
      </FormControl>
    </Box>
  );
};
