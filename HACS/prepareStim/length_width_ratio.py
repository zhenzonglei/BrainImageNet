import cv2
import time
import numpy as np
import pandas as pd

#%% define funcitons
def get_frame_length_width_ratio(video_path):
    """

    Parameters
    ----------
    vid_path[str]: path of the video

    Returns
    -------
    frame_ratio: length-width ratio that corresponds the original frames
    crop_ratio: length-width ratio that corresponds the cropped frames
    """
    vid_cap = cv2.VideoCapture(video_path)
    frame_height = int(vid_cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    frame_width  = int(vid_cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    frame_num = int(vid_cap.get(cv2.CAP_PROP_FRAME_COUNT))
    # loop to get valid frame
    for frame_idx in range(frame_num):
        # Using try to handle situation when the frame is all black
        try:
            vid_cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx) 
            _, frame = vid_cap.read()
            # Compute size of black border if exists
            thresh = 10 # Threshold of pixel value to crop
            y_nonzero, x_nonzero, _ = np.nonzero(frame>thresh)
            # compute crop height and width
            crop_height = np.max(y_nonzero) - np.min(y_nonzero) + 1
            crop_width  = np.max(x_nonzero) - np.min(x_nonzero) + 1
        # if error appears, then continue to the next loop, else break the whole loop
        except Exception:
            continue
        else:
            print(f'Sucessfully compute ratio in frame {frame_idx+1}!')
            break
    # compute ratio
    frame_ratio = round(frame_width/frame_height, 2)
    crop_ratio = round(crop_width/crop_height, 2)
    return frame_ratio, crop_ratio
    
#%% Define params
# define path
dataset_path = '/nfs/e3/VideoDatabase/HACS/training'
working_path = '/nfs/s2/userhome/zhouming/workingdir/Video/HACS/stimulus_select'

#%% get dataframe info
data = pd.read_csv(f'{working_path}/duration.csv')
data = data.sort_values(ascending=True, by='class')
qualified = data[(data['duration'] < 2.05) & (data['duration'] > 1.95) & (data['subset']=='training')]
qualified['label'] = qualified['label'].astype('int64')
qualified = qualified[qualified['label']==1]
# create columns for frame ratio 
qualified.insert(5, 'frame_ratio', 0)
qualified.insert(6, 'crop_ratio', 0)
qualified.drop(['subset'], axis=1, inplace=True)
qualified.reset_index(drop=True, inplace=True)
video_num = qualified.shape[0]
del data

fail = open(f'{working_path}/frame_ratio.txt', 'a+')
fail.seek(0)
time_start = time.time()
for row in qualified.index.values.tolist():
    video_name = qualified.loc[row, 'video']
    class_name = qualified.loc[row, 'class']
    video_path = '/'.join([dataset_path, class_name, video_name])
    try:
        # start to get length_width ratio
        frame_ratio, crop_ratio = get_frame_length_width_ratio(video_path)
    except Exception as e:
        fail.write(f'Error processing {video_name}:{e}\n')
    # add value into dataframe
    qualified.loc[row,'frame_ratio'] = frame_ratio
    qualified.loc[row,'crop_ratio'] = crop_ratio
    time_spent = time.time() - time_start
    print('Finish computing frame size: %d/%d. Time spent %.2fs'%(row+1, video_num, time_spent))
    
qualified.to_csv(f'{working_path}/dataset.csv', index=False)

#%% handle invalid video
# prepare dataset and fail txt
dataset = pd.read_csv(f'{working_path}/dataset.csv')
with open(f'{working_path}/frame_ratio.txt') as f:
    lines = f.readlines()
f.close()
# prepare class name and video name
video_invalid = [x[x.index('v_'):x.index('.mp4')] + '.mp4' for x in lines]
video_class = [x.split('_')[1] for x in video_invalid]
# loop to re compute ratio
for idx,video_name in enumerate(video_invalid):
    class_name = video_class[idx]
    video_path = '/'.join([dataset_path, class_name, video_name])
    # compute ratio
    frame_ratio, crop_ratio = get_frame_length_width_ratio(video_path)
    dataset.loc[dataset['video']==video_name, ['frame_ratio', 'crop_ratio']] = [frame_ratio, crop_ratio]
    print('Video %s: frame ratio %.2f; crop ratio: %.2f'%(video_name, frame_ratio, crop_ratio))

dataset.to_csv(f'{working_path}/dataset.csv', index=False)

#%% filter data
data = pd.read_csv(f'{working_path}/dataset.csv')

# plot hist
data.hist('frame_ratio')
data.hist('crop_ratio')

threshold = (data['frame_ratio'].mean() - 3*data['frame_ratio'].std(),
             data['frame_ratio'].mean() + 3*data['frame_ratio'].std())
filter_data = data.loc[(data['frame_ratio'] > threshold[0]) & \
                       (data['frame_ratio'] < threshold[1]) & \
                       (data['frame_ratio'] == data['crop_ratio'])]
    
    

