import { useEffect, useState } from "react";
import { TextField, TableRow, TableCell, Button, IconButton } from "@mui/material";
import SaveIcon from '@mui/icons-material/Save';
import DeleteIcon from '@mui/icons-material/Delete';
import moment from "moment";
import { useState as useReactState } from "react";
import isString from 'lodash/isString';

export const ThingCreditsRow = ({ credit, updateDebit, deleteDebit }) => {

  const [newAmount, setNewAmount] = useState(null);

  const handleSave = () => {
    console.log("001", credit);
    updateDebit({
      id: credit.id,
      amount: newAmount
    });
  };

  return (
    <TableRow>
      <TableCell>{credit.id}</TableCell>
      <TableCell>
        {credit.member.name}
      </TableCell>
      <TableCell>
        {credit.when}
      </TableCell>
      <TableCell>
        <TextField
          variant="standard"
          type="text"
          inputMode="numeric"
          pattern="[\-0-9\.]*"
          value={isString(newAmount) ? newAmount : credit?.amount}
          onChange={(event) => {
            setNewAmount(event.target.value)
          }}
          onBlur={() => {
            if (isNaN(parseFloat(newAmount))) {
              setNewAmount(null)
            }
          }}
        />
      </TableCell>
      <TableCell sx={{ ...(credit.member.credit_amount < 0 ? { color: "red" } : {}) }}>{credit.member.credit_amount}</TableCell>
      <TableCell>

        {isString(newAmount) && !isNaN(parseFloat(newAmount)) && <IconButton
          title={`Save`}
          onClick={() => {
            handleSave()
          } }
          >
          <SaveIcon />
        </IconButton>}
        <IconButton
          onClick={() => deleteDebit(credit.id)}
          title="Delete credit"
          sx={{ color: 'red' }}
        >
          <DeleteIcon />
        </IconButton>
      </TableCell>
    </TableRow>
  );
};
