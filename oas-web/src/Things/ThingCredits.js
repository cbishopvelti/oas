import { gql, useQuery, useMutation } from "@apollo/client";
import { Box, FormControl, TextField, Button, Table, TableContainer, TableHead, TableRow, TableCell, TableBody, IconButton } from "@mui/material";
import { useEffect, useState as useReactState } from "react";
import { get } from 'lodash';
import moment from "moment";
import AddIcon from '@mui/icons-material/Add';
import SaveIcon from '@mui/icons-material/Save';
import DeleteIcon from '@mui/icons-material/Delete';
import { ThingCreditsRow } from './ThingCreditsRow';
import { Autocomplete } from '@mui/material';

export const ThingCredits = ({
  thingId,
  setCredits
}) => {
  const [addDebit, setAddDebit] = useReactState({
    who_member_id: ''
  });

  const { data, refetch } = useQuery(gql`
    query($thing_id: Int!) {
      thing(id: $thing_id) {
        id,
        credits {
          id,
          member {
            id,
            name,
            credit_amount
          }
          when,
          amount
        }
      }
      members {
        id,
        name
      },

    }
  `, {
    variables: {
      thing_id: thingId
    }
  });

  const credits = get(data, 'thing.credits', []);
  const members = get(data, 'members', [])


  useEffect(() => {
    // TODO
    // setCredits(credits.length);
  }, [credits]);

  const [addDebitMutation] = useMutation(gql`
    mutation($thing_id: Int!, $who_member_id: Int!) {
      thing_add_debit(id: $thing_id, who_member_id: $who_member_id) {
        success
      }
    }
  `);

  const [updateDebitMutation] = useMutation(gql`
    mutation($id: Int!, $amount: String!) {
      save_credit_amount(id: $id, amount: $amount) {
        success
      }
    }
  `);

  const [deleteDebitMutation] = useMutation(gql`
    mutation($credit_id: Int!) {
      thing_delete_debit(credit_id: $credit_id) {
        success
      }
    }
  `);

  const addDebitClick = async () => {
    if (!addDebit.who_member_id) {
      return;
    }
    try {
      await addDebitMutation({
        variables: {
          thing_id: thingId,
          who_member_id: addDebit.who_member_id
        }
      });

      refetch();
    } catch (error) {
      console.error("Error adding credit:", error);
    }
  };

  const updateDebit = async (credit) => {
    try {
      await updateDebitMutation({
        variables: {
          id: credit.id,
          amount: credit.amount
        }
      });

      refetch();
    } catch (error) {
      console.error("Error updating credit:", error);
    }
  };

  const deleteDebit = async (creditId) => {
    try {
      await deleteDebitMutation({
        variables: {
          credit_id: creditId
        }
      });

      refetch();
    } catch (error) {
      console.error("Error deleting credit:", error);
    }
  };

  return (
    <Box sx={{ width: '100%' }}>
      <Box sx={{ display: 'flex', mb: 3, alignItems: 'center' }}>
        <FormControl sx={{mb: 2, minWidth: 256}}>
          <Autocomplete
            id="member"
            value={addDebit.who_member_name || ''}
            options={members.map(({name, id}) => ({label: name, member_id: id }))}
            renderInput={(params) => <TextField {...params} label="Who" />}
            freeSolo
            onChange={(event, newValue, a, b, c, d) => {
              if (!newValue) {
                return
              }
              setAddDebit({
                who_member_id: newValue.member_id,
                who_member_name: newValue.label
              })
            }}
            />
        </FormControl>

        <FormControl sx={{ml: 2, mb: 2}}>
          <Button
            startIcon={<AddIcon />}
            onClick={addDebitClick}
          >
            Purchase
          </Button>
        </FormControl>
      </Box>

      <TableContainer>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>ID</TableCell>
              <TableCell>Who</TableCell>
              <TableCell>When</TableCell>
              <TableCell>Credits used</TableCell>
              <TableCell>Credits remaining</TableCell>
              <TableCell>Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {credits.map((credit) => (
              <ThingCreditsRow
                key={credit.id}
                credit={credit}
                deleteDebit={deleteDebit}
                updateDebit={updateDebit}
              />
            ))}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
};
