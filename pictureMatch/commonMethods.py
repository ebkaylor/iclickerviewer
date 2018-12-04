# using fast implementation of Levenshtein
# https://github.com/aflc/editdistance
import editdistance

# calculates the difference between two image's hash values
def percentHashDifference( curVal, comparisonVal ):
    '''curVal and comparisonVal are of type imagehash.ImageHash
This is basically an 8x8 grid of true/false values that can easily
be converted into a 64-bit ints. Subtraction is defined, and it
returns the bitwise difference between the 64 bit values.

len(curVal.hash) returns 64, because curVal.hash is the actual
8x8 grid, and its length is 8 (8 rows of 8 cols each).

So this function just returns the most obvious thing, which is the
percentage of bits that are changed between two 64-bit values.
    '''
    retval = float((curVal - comparisonVal)) / len( curVal.hash )**2
    # retval = abs(retval)
    return retval

#
# https://www.switchplane.com/blog/improving-search-with-levenshtein-distance/
#
def percentageEditDistance(original, comparison):
    distance = editdistance.eval(original, comparison)
    maxlen = max(len(original), len(comparison))
    if maxlen == 0:
        return 1
    return float(distance)/float(maxlen)


# adds matches to image one to image two
# imageTable holds all the images and meta data
# nameOne and nameTwo are strings representing the keys of the two pics
def addMatchesToEachOther(imageTable, nameOne, nameTwo ):

    # add the current matches of nameTwo to each of the matches in nameOne
    # need to union with set([nameTwo]) because the matches of nameTwo will
    # not have nameTwo in the set
    for matches in imageTable[nameOne]["matchNamesRemove"]:
        imageTable[matches]["matchNamesRemove"] =imageTable[matches]["matchNamesRemove"] | \
                                        imageTable[nameTwo]["matchNamesRemove"] | set([nameTwo])
        imageTable[matches]["matchNamesRemove"].discard(matches) # in case the same element has been added to itselfas a match

    # same as above but in the other order
    for matches in imageTable[nameTwo]["matchNamesRemove"]:
        imageTable[matches]["matchNamesRemove"] =imageTable[matches]["matchNamesRemove"] | \
                                        imageTable[nameOne]["matchNamesRemove"] | set([nameOne])
        imageTable[matches]["matchNamesRemove"].discard(matches) # in case the same element has been added as a match

    # union the matches of nameOne and nameTwo and set them as the matches of nameOne and nameTwo
    imageTable[nameOne]["matchNamesRemove"] =imageTable[nameOne]["matchNamesRemove"]| \
                                           imageTable[nameTwo]["matchNamesRemove"]


    imageTable[nameTwo]["matchNamesRemove"] =imageTable[nameTwo]["matchNamesRemove"]| \
                                           imageTable[nameOne]["matchNamesRemove"]

    # add nameOne and nameTwo to the respective sets because no elements will contain themselves
    imageTable[nameOne]["matchNamesRemove"] =imageTable[nameOne]["matchNamesRemove"]| set([nameTwo])
    imageTable[nameTwo]["matchNamesRemove"] =imageTable[nameTwo]["matchNamesRemove"]| set([nameOne])

    # remove if an element has been added to itself
    imageTable[nameOne]["matchNamesRemove"].discard(nameOne)
    imageTable[nameTwo]["matchNamesRemove"].discard(nameTwo)

    return imageTable

# removes items from of the key using the removelist
def removeItemsFromSet( imageTable, key, removeList  ):

    # remove the key as a match from every element in the removelist
    for elem in removeList:
        imageTable[elem]["matchNamesRemove"].discard(key)

    imageTable[key]["matchNamesRemove"] = imageTable[key]["matchNamesRemove"] - set(removeList)

# takes care of elements that do not have any matches
# adds those elements to an element before or after and updates the
# match list accordingly
# singulars is a list of elements that have not found any preliminary
# matches
def addSingulars( imageTable, singulars ):

    for elem in singulars:

        # isolate which number of the question
        name = elem
        qIndex = name.rfind("Q")
        number = int( name[ qIndex + 1: -4 ] )
        oneLess = number - 1
        oneMore = number + 1

        # check the number before
        imgNameBefore = name[:qIndex+1] + str(oneLess) + ".jpg"

        #check the number after
        imgNameAfter = name[:qIndex+1] + str(oneMore) + ".jpg"

        # the closer one will be the one who you should add it to
        curImgText = imageTable[name]["ocr_text"]

        # try blocks are if the imgNameBefore or After does not exist in the
        # table
        # can be replaced with if statement and in keyword
        # calculate the editdistance and use the smaller of the two values
        try:
            textImgBefore = imageTable[imgNameBefore]["ocr_text"]
            distBefore = editDistance.editDistDP( textImgBefore, curImgText )
        except KeyError:
            distBefore = -1

        try:
            textImgAfter = imageTable[imgNameAfter]["ocr_text"]
            distAfter = editDistance.editDistDP( textImgAfter, curImgText )
        except KeyError:
            distAfter = -1
        toBeAdded = None

    # if any of the distances are -1 then use the other value
    # they both cannot be -1 if there is more than 1 picture in a directory
    # otherwise use the editdistances that is the smallest
    if distBefore == -1:
        toBeAdded = imgNameAfter
    elif distAfter == -1:
        toBeAdded = imgNameBefore
    else:
        if distBefore < distAfter:
            toBeAdded = imgNameBefore
        else:
            toBeAdded = imgNameAfter
        #figure out what the algorithm is to add elements here
        addMatchesToEachOther( imageTable, name, toBeAdded  )

    return imageTable
