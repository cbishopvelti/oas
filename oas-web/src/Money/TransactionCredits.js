import { useState, useEffect } from "react"
import {TextField, FormControl, FormControlLabel, Switch, InputLabel, Select, MenuItem } from "@mui/material"
import { get, omit, has } from "lodash"
import { useQuery, gql } from "@apollo/client"


export const TransactionCredits = ({
  id,
  formData,
  setFormData,
  data,
  errors
}) => {
  const isDisabled = !formData.who_member_id

  useEffect(() => {
    if (isDisabled) {
      setFormData(
        omit(formData, "credit")
      )
    }
  }, [isDisabled])

  // useEffect(() => {
  //   if(!buyingCredits) {
  //     setFormData(
  //       omit(formData, "credit")
  //     )
  //   } else if(buyingCredits) {
  //     setFormData({
  //       ...formData,
  //       credit: {
  //         amount: formData?.credit?.amount
  //       }
  //     })
  //   }
  // }, [buyingCredits])

  useEffect(() => {
    if (!!formData.credit && formData.credit.amount !== formData.amount) {
      setFormData({
        ...formData,
        credit: {
          amount: formData.amount
        }
      })
    }
  }, [formData.amount])

  useEffect(() => {
    if (formData.credit && !formData?.credit?.amount) {
      setFormData({
        ...formData,
        credit: {
          amount: formData.amount
        }
      })
    }
  }, [formData.credit])

  return (<>
    <FormControl fullWidth sx={{m:2}}>
      <FormControlLabel
        control={
          <Switch
            disabled={isDisabled}
            checked={!!formData.credit}
            onChange={(event) => {
              if (event.target.checked) {
                setFormData({
                  ...formData,
                  credit: {
                  }
                })
              } else {
                setFormData(omit(formData, "credit"))
              }
            }} />
        }
        label="Credits" />
    </FormControl>
    {
      formData.credit && <FormControl fullWidth sx={{m: 2}}>
        {/* <InputLabel id="credits">Credits amount</InputLabel> */}
        <TextField
          label="Credits amount"
          value={get(formData, "credit.amount", 0.0) || get(data, "amount", 0.0)}
          type="text"
          inputMode="numeric"
          pattern="[0-9\.]*"
          required
          onChange={(event) => {
            let amount = event.target.value;
            if (event.target.value === '') {
              amount = '0';
            }
            setFormData({
              ...formData,
              credit: {
                amount: amount
              }
            })
          }}
          error={has(errors, "credit.amount")}
          helperText={get(errors, "credit.amount", []).join(' ')}
        />
      </FormControl>
    }
  </>)
}
